using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using PulseCity.Application.Interfaces;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;
using PulseCity.Infrastructure.Options;

namespace PulseCity.Infrastructure.Services;

public sealed class PrivacyRetentionHostedService(
    IServiceScopeFactory scopeFactory,
    IHostEnvironment hostEnvironment,
    IOptions<StorageOptions> storageOptions,
    IRealtimeNotifier realtimeNotifier
) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await PurgeExpiredExportsAsync(stoppingToken);
                await PurgeExpiredStoriesAsync(stoppingToken);
                await PurgeExpiredTemporaryChatsAsync(stoppingToken);
            }
            catch
            {
                // Swallow background cleanup errors; they should not bring down the API.
            }

            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }

    private async Task PurgeExpiredExportsAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<PulseCityDbContext>();

        var expired = await dbContext.UserDataExports
            .Where(entry => entry.ExpiresAt <= DateTimeOffset.UtcNow)
            .ToListAsync(cancellationToken);

        if (expired.Count == 0)
        {
            return;
        }

        foreach (var export in expired)
        {
            var filePath = ResolveExportPath(export.RelativePath);

            if (File.Exists(filePath))
            {
                try
                {
                    File.Delete(filePath);
                }
                catch
                {
                    // Ignore delete failures; row will be retried on next pass.
                    continue;
                }
            }
        }

        foreach (var export in expired)
        {
            var filePath = ResolveExportPath(export.RelativePath);
            if (File.Exists(filePath))
            {
                continue;
            }

            await dbContext.Database.ExecuteSqlInterpolatedAsync(
                $"EXEC dbo.usp_DeleteUserDataExport @ExportId={export.Id}",
                cancellationToken
            );
        }
    }

    private async Task PurgeExpiredStoriesAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<PulseCityDbContext>();

        var expiredStories = await dbContext.Highlights
            .Where(entry =>
                entry.EntryKind == "story"
                && entry.ExpiresAt.HasValue
                && entry.ExpiresAt <= DateTimeOffset.UtcNow)
            .ToListAsync(cancellationToken);

        if (expiredStories.Count == 0)
        {
            return;
        }

        var affectedUserIds = expiredStories
            .Select(entry => entry.UserId)
            .Where(entry => !string.IsNullOrWhiteSpace(entry))
            .Distinct(StringComparer.Ordinal)
            .ToList();

        dbContext.Highlights.RemoveRange(expiredStories);
        await dbContext.SaveChangesAsync(cancellationToken);

        foreach (var userId in affectedUserIds)
        {
            await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
        }
    }

    private async Task PurgeExpiredTemporaryChatsAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<PulseCityDbContext>();

        var expiredChats = await dbContext.Chats
            .Where(entry =>
                entry.IsTemporary
                && entry.ExpiresAt.HasValue
                && entry.ExpiresAt <= DateTimeOffset.UtcNow)
            .ToListAsync(cancellationToken);

        if (expiredChats.Count == 0) return;

        var chatIds = expiredChats.Select(c => c.Id).ToList();

        // Hard-delete messages and participants for expired chats
        var messages = await dbContext.ChatMessages
            .Where(m => chatIds.Contains(m.ChatId))
            .ToListAsync(cancellationToken);
        dbContext.ChatMessages.RemoveRange(messages);

        var participants = await dbContext.ChatParticipants
            .Where(p => chatIds.Contains(p.ChatId))
            .ToListAsync(cancellationToken);
        dbContext.ChatParticipants.RemoveRange(participants);

        dbContext.Chats.RemoveRange(expiredChats);
        await dbContext.SaveChangesAsync(cancellationToken);

        // Notify participants that chats were deleted
        foreach (var chat in expiredChats)
        {
            var participantIds = participants
                .Where(p => p.ChatId == chat.Id)
                .Select(p => p.UserId)
                .ToArray();
            if (participantIds.Length > 0)
            {
                await realtimeNotifier.NotifyChatUpdatedAsync(
                    chat.Id,
                    participantIds,
                    cancellationToken: cancellationToken
                );
            }
        }
    }

    private string ResolveExportPath(string relativePath)
    {
        var normalized = relativePath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
        var privateRoot = StoragePathResolver.ResolveExportRoot(
            hostEnvironment,
            storageOptions.Value
        );
        var privatePath = Path.Combine(privateRoot, normalized);
        if (File.Exists(privatePath))
        {
            return privatePath;
        }

        var uploadRoot = StoragePathResolver.ResolveLegacyPublicRoot(
            hostEnvironment,
            storageOptions.Value
        );
        return Path.Combine(
            uploadRoot,
            normalized.Replace(
                $"uploads{Path.DirectorySeparatorChar}",
                string.Empty,
                StringComparison.OrdinalIgnoreCase
            )
        );
    }
}
