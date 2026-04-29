using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;

namespace PulseCity.Infrastructure.Services;

/// <summary>
/// Periodically scans for activities whose reminder window has been reached and
/// fans out a single ActivityReminder notification to each approved participant.
/// Uses Activity.ReminderSent as an idempotency flag.
/// </summary>
public sealed class ActivityReminderHostedService(
    IServiceScopeFactory scopeFactory,
    ILogger<ActivityReminderHostedService> logger
) : BackgroundService
{
    private static readonly TimeSpan PollInterval = TimeSpan.FromMinutes(1);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessRemindersAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Activity reminder pass failed.");
            }

            try
            {
                await Task.Delay(PollInterval, stoppingToken);
            }
            catch (TaskCanceledException)
            {
                break;
            }
        }
    }

    private async Task ProcessRemindersAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<PulseCityDbContext>();
        var notificationsService = scope.ServiceProvider.GetRequiredService<INotificationsService>();

        var now = DateTimeOffset.UtcNow;

        var due = await dbContext.Activities
            .Where(a => a.Status == ActivityStatus.Published
                && !a.ReminderSent
                && a.StartsAt > now
                && EF.Functions.DateDiffMinute(now, a.StartsAt) <= a.ReminderMinutesBefore)
            .ToListAsync(cancellationToken);

        if (due.Count == 0) return;

        foreach (var activity in due)
        {
            var participantIds = await dbContext.ActivityParticipations.AsNoTracking()
                .Where(p => p.ActivityId == activity.Id
                    && p.Status == ActivityParticipationStatus.Approved)
                .Select(p => p.UserId)
                .ToListAsync(cancellationToken);

            var minutesUntil = Math.Max(0, (int)Math.Round((activity.StartsAt - now).TotalMinutes));
            var body = minutesUntil <= 0
                ? $"\"{activity.Title}\" başlıyor!"
                : $"\"{activity.Title}\" {minutesUntil} dk sonra başlıyor";

            foreach (var recipientId in participantIds)
            {
                _ = notificationsService.CreateAsync(
                    recipientId,
                    NotificationType.ActivityReminder,
                    activity.Title,
                    body,
                    actorUserId: activity.HostUserId,
                    deepLink: $"/activities/{activity.Id}",
                    relatedEntityType: "Activity",
                    relatedEntityId: activity.Id.ToString(),
                    cancellationToken: cancellationToken
                );
            }

            // Also remind the host so they don't oversleep their own meetup.
            _ = notificationsService.CreateAsync(
                activity.HostUserId,
                NotificationType.ActivityReminder,
                activity.Title,
                body,
                actorUserId: null,
                deepLink: $"/activities/{activity.Id}",
                relatedEntityType: "Activity",
                relatedEntityId: activity.Id.ToString(),
                cancellationToken: cancellationToken
            );

            activity.ReminderSent = true;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
