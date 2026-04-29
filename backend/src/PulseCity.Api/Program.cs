using System.Security.Claims;
using System.Text;
using Azure.Extensions.AspNetCore.Configuration.Secrets;
using Azure.Identity;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.FileProviders;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.OpenApi.Models;
using System.Threading.RateLimiting;
using PulseCity.Application.Interfaces;
using PulseCity.Api.Services;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Extensions;
using PulseCity.Infrastructure.Internal;
using PulseCity.Infrastructure.Options;

var builder = WebApplication.CreateBuilder(args);
if (builder.Environment.IsDevelopment())
{
    builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);
}

// Azure Key Vault secret overlay. Secrets in the vault override any matching
// key from appsettings.json / env vars, so production deploys can keep
// appsettings.json free of credentials. The source is skipped silently when
// no vault URI is configured (e.g. in local dev without Azure sign-in).
var keyVaultOptions =
    builder.Configuration.GetSection(KeyVaultOptions.SectionName).Get<KeyVaultOptions>()
    ?? new KeyVaultOptions();
if (!string.IsNullOrWhiteSpace(keyVaultOptions.Uri)
    && Uri.TryCreate(keyVaultOptions.Uri, UriKind.Absolute, out var vaultUri))
{
    var reloadInterval = TimeSpan.FromMinutes(
        Math.Clamp(keyVaultOptions.ReloadIntervalMinutes, 1, 1440)
    );
    builder.Configuration.AddAzureKeyVault(
        vaultUri,
        new DefaultAzureCredential(),
        new AzureKeyVaultConfigurationOptions
        {
            ReloadInterval = reloadInterval,
        }
    );
}

builder.Services.AddControllers();
builder.Services.AddSignalR();
builder.Services.AddProblemDetails();
builder.Services.AddOpenApi();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "PulseCity API",
        Version = "v1",
        Description = "Hybrid backend for PulseCity mobile app.",
    });

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        In = ParameterLocation.Header,
        Description = "PulseCity JWT bearer token.",
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer",
                },
            },
            Array.Empty<string>()
        },
    });
});

builder.Services.AddPulseCityInfrastructure(builder.Configuration, builder.Environment);
builder.Services.AddSingleton<IRealtimeNotifier, RealtimeNotifier>();
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders =
        ForwardedHeaders.XForwardedFor
        | ForwardedHeaders.XForwardedProto
        | ForwardedHeaders.XForwardedHost;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});
var jwtOptions =
    builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>()
    ?? new JwtOptions();
if (string.IsNullOrWhiteSpace(jwtOptions.SigningKey))
{
    throw new InvalidOperationException(
        "PulseCity:Jwt:SigningKey must be configured before the API can start."
    );
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrWhiteSpace(accessToken)
                    && path.StartsWithSegments(new PathString("/hubs")))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            },
        };
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtOptions.SigningKey)
            ),
            ClockSkew = TimeSpan.FromMinutes(2),
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    // Per-IP policies (unauthenticated surface: login / registration / password-reset).
    options.AddPolicy("auth", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: $"auth:{context.Connection.RemoteIpAddress?.ToString() ?? "unknown"}",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            }
        ));
    options.AddPolicy("password-reset", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: $"password-reset:{context.Connection.RemoteIpAddress?.ToString() ?? "unknown"}",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(15),
                QueueLimit = 0,
            }
        ));

    // Per-user policies for authenticated dating flows. Partitioning by userId
    // prevents two devices on the same NAT from sharing the same bucket, while
    // still blocking abuse at the account level. Falls back to IP if the user
    // is somehow unauthenticated (defensive — all target endpoints are [Authorize]).
    static string UserPartition(HttpContext context, string prefix)
    {
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        return !string.IsNullOrEmpty(userId)
            ? $"{prefix}:u:{userId}"
            : $"{prefix}:ip:{context.Connection.RemoteIpAddress?.ToString() ?? "unknown"}";
    }

    // Discover reads + pass/undo writes. Power swipers can rip through 100+
    // cards per minute; 240 leaves headroom for double-taps and refills,
    // while still catching scraper bots.
    options.AddPolicy("discover", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: UserPartition(context, "discover"),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 240,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            }
        ));

    // Creating a match is expensive (DB writes + FCM push to the target user)
    // and is the main spam vector — keep this tight.
    options.AddPolicy("match-write", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: UserPartition(context, "match-write"),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            }
        ));

    // Reading the match list / incoming likes. Cheap; allow frequent polling.
    options.AddPolicy("match-read", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: UserPartition(context, "match-read"),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 120,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            }
        ));
});

var corsOptions =
    builder.Configuration.GetSection(CorsOptions.SectionName).Get<CorsOptions>() ?? new CorsOptions();
var allowedOrigins = corsOptions.AllowedOrigins.Count > 0
    ? corsOptions.AllowedOrigins
    : ["http://localhost:3000", "http://localhost:5275", "http://10.0.2.2:5275"];

builder.Services.AddCors(options =>
{
    options.AddPolicy("MobileApp", policy =>
    {
        policy.WithOrigins(allowedOrigins.ToArray()).AllowAnyHeader().AllowAnyMethod().AllowCredentials();
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseHsts();
}

var storageOptions =
    app.Services.GetRequiredService<IConfiguration>()
        .GetSection(StorageOptions.SectionName)
        .Get<StorageOptions>()
    ?? new StorageOptions();
var uploadRoot = Path.GetFullPath(
    StoragePathResolver.ResolvePublicRoot(app.Environment, storageOptions)
);
Directory.CreateDirectory(uploadRoot);
var legacyUploadRoot = StoragePathResolver.ResolveLegacyPublicRoot(app.Environment, storageOptions);
var uploadProviders = new List<IFileProvider>
{
    new PhysicalFileProvider(uploadRoot),
};
if (!string.Equals(uploadRoot, legacyUploadRoot, StringComparison.OrdinalIgnoreCase)
    && Directory.Exists(legacyUploadRoot))
{
    uploadProviders.Add(new PhysicalFileProvider(legacyUploadRoot));
}

var databaseOptions =
    app.Services.GetRequiredService<IConfiguration>()
        .GetSection(DatabaseOptions.SectionName)
        .Get<DatabaseOptions>()
    ?? new DatabaseOptions();

if (databaseOptions.ApplyMigrationsOnStartup)
{
    using var scope = app.Services.CreateScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<PulseCityDbContext>();
    await dbContext.Database.MigrateAsync();
}

app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        var exception = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>()?.Error;
        var (statusCode, message) = exception switch
        {
            InvalidOperationException invalidOperation => (StatusCodes.Status400BadRequest, invalidOperation.Message),
            UnauthorizedAccessException unauthorized => (StatusCodes.Status401Unauthorized, unauthorized.Message),
            _ => (StatusCodes.Status500InternalServerError, "An unexpected error occurred while processing your request."),
        };

        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(new { message });
    });
});
app.UseForwardedHeaders();
app.UseHttpsRedirection();
app.Use(async (context, next) =>
{
    var headers = context.Response.Headers;
    headers.Append("X-Content-Type-Options", "nosniff");
    headers.Append("X-Frame-Options", "DENY");
    headers.Append("X-XSS-Protection", "1; mode=block");
    headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    headers.Append("Content-Security-Policy", "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'");
    if (context.Request.IsHttps)
    {
        headers.Append("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
    }
    await next();
});
app.UseStaticFiles(
    new StaticFileOptions
    {
        FileProvider = uploadProviders.Count == 1
            ? uploadProviders[0]
            : new CompositeFileProvider(uploadProviders),
        RequestPath = storageOptions.PublicBasePath,
    }
);
app.UseCors("MobileApp");
app.UseAuthentication();
app.UseAuthorization();
// Rate limiter must run AFTER authentication so per-user partitions can read
// ClaimTypes.NameIdentifier. IP-only policies (auth, password-reset) are
// unaffected by this ordering.
app.UseRateLimiter();

app.MapControllers();
app.MapHub<PulseCity.Api.Hubs.PulsePresenceHub>("/hubs/presence");
app.MapHub<PulseCity.Api.Hubs.PulseRealtimeHub>("/hubs/realtime");

app.Run();
