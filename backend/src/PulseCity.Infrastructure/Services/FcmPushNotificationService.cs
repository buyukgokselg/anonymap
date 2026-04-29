using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Options;

namespace PulseCity.Infrastructure.Services;

public sealed class FcmPushNotificationService : IPushNotificationService
{
    private readonly PulseCityDbContext _dbContext;
    private readonly ILogger<FcmPushNotificationService> _logger;
    private readonly bool _enabled;
    private static readonly Lock _lock = new();
    private static bool _firebaseInitialized = false;

    public FcmPushNotificationService(
        PulseCityDbContext dbContext,
        IOptions<PushNotificationOptions> options,
        ILogger<FcmPushNotificationService> logger
    )
    {
        _dbContext = dbContext;
        _logger = logger;
        var fcmOptions = options.Value;

        if (string.IsNullOrWhiteSpace(fcmOptions.ProjectId))
        {
            logger.LogWarning("FCM is disabled: PulseCity:Fcm:ProjectId is not configured.");
            return;
        }

        lock (_lock)
        {
            if (_firebaseInitialized)
            {
                _enabled = true;
                return;
            }

            try
            {
                var credential = ResolveCredential(fcmOptions, logger);
                if (credential is null)
                {
                    logger.LogWarning(
                        "FCM is disabled: no service account credential could be resolved. "
                            + "Configure one of PulseCity:Fcm:ServiceAccountJson, "
                            + "PulseCity:Fcm:ServiceAccountJsonFile, or the "
                            + "GOOGLE_APPLICATION_CREDENTIALS environment variable."
                    );
                    return;
                }

                if (FirebaseApp.DefaultInstance is null)
                {
                    FirebaseApp.Create(new AppOptions
                    {
                        Credential = credential,
                        ProjectId = fcmOptions.ProjectId,
                    });
                }

                _firebaseInitialized = true;
                _enabled = true;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to initialize Firebase Admin SDK.");
            }
        }
    }

    private static GoogleCredential? ResolveCredential(
        PushNotificationOptions fcmOptions,
        ILogger<FcmPushNotificationService> logger
    )
    {
        // 1) Inline JSON (preferred for Azure Key Vault / env var overlay)
        if (!string.IsNullOrWhiteSpace(fcmOptions.ServiceAccountJson))
        {
            return GoogleCredential.FromJson(fcmOptions.ServiceAccountJson);
        }

        // 2) File on disk (for Key Vault references mounted as files on App Service)
        if (!string.IsNullOrWhiteSpace(fcmOptions.ServiceAccountJsonFile))
        {
            var path = Environment.ExpandEnvironmentVariables(fcmOptions.ServiceAccountJsonFile);
            if (!File.Exists(path))
            {
                logger.LogError(
                    "FCM credential file not found at {Path}. Check PulseCity:Fcm:ServiceAccountJsonFile.",
                    path
                );
                return null;
            }

            using var stream = File.OpenRead(path);
            return GoogleCredential.FromStream(stream);
        }

        // 3) GOOGLE_APPLICATION_CREDENTIALS env var or GCE metadata — baseline fallback
        var adcPath = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS");
        if (!string.IsNullOrWhiteSpace(adcPath) && File.Exists(adcPath))
        {
            return GoogleCredential.GetApplicationDefault();
        }

        return null;
    }

    public async Task RegisterTokenAsync(string userId, string token, string platform, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(token)) return;

        var existing = await _dbContext.DeviceTokens
            .FirstOrDefaultAsync(entry => entry.Token == token, cancellationToken);

        if (existing is not null)
        {
            existing.UserId = userId;
            existing.Platform = platform;
            existing.UpdatedAt = DateTimeOffset.UtcNow;
        }
        else
        {
            _dbContext.DeviceTokens.Add(new DeviceToken
            {
                UserId = userId,
                Token = token,
                Platform = platform,
                RegisteredAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow,
            });
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task UnregisterTokenAsync(string userId, string token, CancellationToken cancellationToken = default)
    {
        var existing = await _dbContext.DeviceTokens
            .FirstOrDefaultAsync(entry => entry.UserId == userId && entry.Token == token, cancellationToken);

        if (existing is not null)
        {
            _dbContext.DeviceTokens.Remove(existing);
            await _dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task SendToUserAsync(string userId, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default)
    {
        if (!_enabled) return;
        await SendToUsersAsync([userId], title, body, data, cancellationToken);
    }

    public async Task SendToUsersAsync(IEnumerable<string> userIds, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default)
    {
        if (!_enabled) return;

        var ids = userIds.ToList();
        if (ids.Count == 0) return;

        var tokens = await _dbContext.DeviceTokens
            .AsNoTracking()
            .Where(entry => ids.Contains(entry.UserId))
            .Select(entry => entry.Token)
            .Distinct()
            .ToListAsync(cancellationToken);

        if (tokens.Count == 0) return;

        var messaging = FirebaseMessaging.DefaultInstance;
        var staleTokens = new List<string>();

        foreach (var batch in tokens.Chunk(500))
        {
            var message = new MulticastMessage
            {
                Tokens = batch.ToList(),
                Notification = new FirebaseAdmin.Messaging.Notification { Title = title, Body = body },
                Data = data ?? new Dictionary<string, string>(),
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        Sound = "default",
                        ClickAction = "FLUTTER_NOTIFICATION_CLICK",
                    },
                },
            };

            try
            {
                var response = await messaging.SendEachForMulticastAsync(message, cancellationToken);
                for (int i = 0; i < response.Responses.Count; i++)
                {
                    var resp = response.Responses[i];
                    if (!resp.IsSuccess &&
                        (resp.Exception?.MessagingErrorCode == MessagingErrorCode.Unregistered ||
                         resp.Exception?.MessagingErrorCode == MessagingErrorCode.InvalidArgument))
                    {
                        staleTokens.Add(batch[i]);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "FCM send failed for batch of {Count} tokens.", batch.Length);
            }
        }

        if (staleTokens.Count > 0)
        {
            var toRemove = await _dbContext.DeviceTokens
                .Where(entry => staleTokens.Contains(entry.Token))
                .ToListAsync(cancellationToken);
            _dbContext.DeviceTokens.RemoveRange(toRemove);
            await _dbContext.SaveChangesAsync(cancellationToken);
        }
    }
}
