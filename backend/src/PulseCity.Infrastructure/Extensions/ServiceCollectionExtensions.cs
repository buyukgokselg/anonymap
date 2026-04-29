using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using PulseCity.Application.Interfaces;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Options;
using PulseCity.Infrastructure.Services;

namespace PulseCity.Infrastructure.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddPulseCityInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment
    )
    {
        services.Configure<DatabaseOptions>(configuration.GetSection(DatabaseOptions.SectionName));
        services.Configure<RedisOptions>(configuration.GetSection(RedisOptions.SectionName));
        services.Configure<GooglePlacesOptions>(configuration.GetSection(GooglePlacesOptions.SectionName));
        services.Configure<CorsOptions>(configuration.GetSection(CorsOptions.SectionName));
        services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));
        services.Configure<StorageOptions>(configuration.GetSection(StorageOptions.SectionName));
        services.Configure<PrivacyOptions>(configuration.GetSection(PrivacyOptions.SectionName));
        services.Configure<SmtpOptions>(configuration.GetSection(SmtpOptions.SectionName));
        services.Configure<PushNotificationOptions>(configuration.GetSection(PushNotificationOptions.SectionName));
        services.Configure<KeyVaultOptions>(configuration.GetSection(KeyVaultOptions.SectionName));

        services.AddDbContext<PulseCityDbContext>(options =>
        {
            var connectionString = configuration.GetConnectionString("SqlServer")
                ?? throw new InvalidOperationException("ConnectionStrings:SqlServer is missing.");
            options.UseSqlServer(connectionString);
        });

        var redisOptions =
            configuration.GetSection(RedisOptions.SectionName).Get<RedisOptions>() ?? new RedisOptions();
        if (string.IsNullOrWhiteSpace(redisOptions.ConnectionString))
        {
            services.AddDistributedMemoryCache();
        }
        else
        {
            services.AddStackExchangeRedisCache(options =>
            {
                options.Configuration = redisOptions.ConnectionString;
                options.InstanceName = redisOptions.InstanceName;
            });
        }

        services.AddHttpClient<PlacesService>(client =>
        {
            client.Timeout = TimeSpan.FromSeconds(10);
            client.DefaultRequestHeaders.UserAgent.ParseAdd("PulseCity-Backend/1.0");
        });

        services.AddSingleton<JwtTokenService>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IChatsService, ChatsService>();
        services.AddScoped<IHighlightsService, HighlightsService>();
        services.AddScoped<IMatchesService, MatchesService>();
        services.AddScoped<IPresenceService, PresenceService>();
        services.AddScoped<IUsersService, UsersService>();
        services.AddScoped<ISocialService, SocialService>();
        services.AddScoped<IPostsService, PostsService>();
        services.AddScoped<IPlacesService, PlacesService>();
        services.AddSingleton<IFileStorageService, LocalFileStorageService>();
        services.AddSingleton<IEmailSender, SmtpEmailSender>();
        services.AddScoped<IPushNotificationService, FcmPushNotificationService>();
        services.AddScoped<INotificationsService, NotificationsService>();
        services.AddScoped<IActivitiesService, ActivitiesService>();
        services.AddScoped<IBadgesService, BadgesService>();
        services.AddHostedService<PrivacyRetentionHostedService>();
        services.AddHostedService<ActivityReminderHostedService>();

        return services;
    }
}
