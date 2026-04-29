using Microsoft.EntityFrameworkCore;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;

namespace PulseCity.Infrastructure.Services;

public sealed class ActivitiesService(
    PulseCityDbContext dbContext,
    INotificationsService notificationsService,
    IRealtimeNotifier realtimeNotifier,
    IChatsService chatsService,
    IBadgesService badgesService
) : IActivitiesService
{
    private const int SampleParticipantLimit = 6;

    public async Task<ActivityDto> CreateAsync(
        string hostUserId,
        CreateActivityRequest request,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(hostUserId))
        {
            throw new ArgumentException("Host user id is required.", nameof(hostUserId));
        }
        if (request.StartsAt <= DateTimeOffset.UtcNow.AddMinutes(-1))
        {
            throw new InvalidOperationException("Activity start time must be in the future.");
        }
        if (request.EndsAt is { } endsAt && endsAt <= request.StartsAt)
        {
            throw new InvalidOperationException("Activity end time must be after start time.");
        }
        if (request.MinAge.HasValue && request.MaxAge.HasValue && request.MinAge > request.MaxAge)
        {
            throw new InvalidOperationException("MinAge cannot exceed MaxAge.");
        }

        var category = ParseEnum(request.Category, ActivityCategory.Other);
        var visibility = ParseEnum(request.Visibility, ActivityVisibility.Public);
        var joinPolicy = ParseEnum(request.JoinPolicy, ActivityJoinPolicy.Open);

        var activity = new Activity
        {
            HostUserId = hostUserId,
            Title = request.Title.Trim(),
            Description = request.Description?.Trim() ?? string.Empty,
            Category = category,
            Mode = string.IsNullOrWhiteSpace(request.Mode) ? "chill" : request.Mode.Trim(),
            CoverImageUrl = string.IsNullOrWhiteSpace(request.CoverImageUrl) ? null : request.CoverImageUrl.Trim(),
            LocationName = request.LocationName.Trim(),
            LocationAddress = string.IsNullOrWhiteSpace(request.LocationAddress) ? null : request.LocationAddress.Trim(),
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            City = request.City.Trim(),
            NormalizedCity = TextNormalizer.Normalize(request.City),
            PlaceId = string.IsNullOrWhiteSpace(request.PlaceId) ? null : request.PlaceId.Trim(),
            StartsAt = request.StartsAt,
            EndsAt = request.EndsAt,
            ReminderMinutesBefore = request.ReminderMinutesBefore,
            MaxParticipants = request.MaxParticipants,
            Visibility = visibility,
            JoinPolicy = joinPolicy,
            RequiresVerification = request.RequiresVerification,
            Interests = (request.Interests ?? [])
                .Select(t => t.Trim())
                .Where(t => !string.IsNullOrEmpty(t))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Take(20)
                .ToList(),
            MinAge = request.MinAge,
            MaxAge = request.MaxAge,
            PreferredGender = string.IsNullOrWhiteSpace(request.PreferredGender) ? "any" : request.PreferredGender.Trim().ToLowerInvariant(),
            RecurrenceRule = NormalizeRecurrenceRule(request.RecurrenceRule),
            RecurrenceUntil = request.RecurrenceUntil,
            Status = ActivityStatus.Published,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        dbContext.Activities.Add(activity);
        await dbContext.SaveChangesAsync(cancellationToken);

        await EnsureActivityChatAsync(activity, cancellationToken);

        await realtimeNotifier.NotifyActivityChangedAsync(
            activity.Id,
            new[] { hostUserId },
            "created",
            cancellationToken);

        // Host'un Host rozet ilerlemesini güncelle (kazanılan tier varsa bildirim gönderilir).
        await badgesService.RecomputeAsync(hostUserId, cancellationToken);

        return await BuildDtoAsync(activity, hostUserId, cancellationToken)
            ?? throw new InvalidOperationException("Activity DTO could not be built after creation.");
    }

    public async Task<ActivityDto?> GetAsync(
        Guid activityId,
        string viewerUserId,
        CancellationToken cancellationToken = default
    )
    {
        var activity = await dbContext.Activities.AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == activityId, cancellationToken);
        if (activity is null) return null;

        if (!await CanViewAsync(activity, viewerUserId, cancellationToken))
        {
            return null;
        }

        return await BuildDtoAsync(activity, viewerUserId, cancellationToken);
    }

    public async Task<ActivityListResponseDto> SearchAsync(
        string viewerUserId,
        ActivityListQuery query,
        CancellationToken cancellationToken = default
    )
    {
        var limit = Math.Clamp(query.Limit <= 0 ? 20 : query.Limit, 1, 50);
        var now = DateTimeOffset.UtcNow;

        var baseQuery = dbContext.Activities.AsNoTracking()
            .Where(a => a.Status == ActivityStatus.Published)
            .Where(a => a.StartsAt >= now);

        if (!string.IsNullOrWhiteSpace(query.Category))
        {
            if (Enum.TryParse<ActivityCategory>(query.Category, ignoreCase: true, out var cat))
            {
                baseQuery = baseQuery.Where(a => a.Category == cat);
            }
        }
        if (!string.IsNullOrWhiteSpace(query.Mode))
        {
            var mode = query.Mode.Trim();
            baseQuery = baseQuery.Where(a => a.Mode == mode);
        }
        if (!string.IsNullOrWhiteSpace(query.City))
        {
            var normalized = TextNormalizer.Normalize(query.City);
            baseQuery = baseQuery.Where(a => a.NormalizedCity == normalized);
        }
        if (!string.IsNullOrWhiteSpace(query.When))
        {
            var (from, to) = ResolveWhenWindow(query.When, now);
            if (from is { } fromValue) baseQuery = baseQuery.Where(a => a.StartsAt >= fromValue);
            if (to is { } toValue) baseQuery = baseQuery.Where(a => a.StartsAt < toValue);
        }
        if (query.After is { } cursor)
        {
            baseQuery = baseQuery.Where(a => a.StartsAt > cursor);
        }
        if (query.HostUserId is { } hostId)
        {
            var hostKey = hostId.ToString();
            baseQuery = baseQuery.Where(a => a.HostUserId == hostKey);
        }

        // Visibility prefilter — coarse, refined per-row below
        baseQuery = baseQuery.Where(a =>
            a.Visibility == ActivityVisibility.Public
            || a.HostUserId == viewerUserId);

        var rows = await baseQuery
            .OrderBy(a => a.StartsAt)
            .Take(limit + 1)
            .ToListAsync(cancellationToken);

        var hasMore = rows.Count > limit;
        if (hasMore) rows.RemoveAt(rows.Count - 1);

        if (query.CenterLatitude is { } centerLat
            && query.CenterLongitude is { } centerLng
            && query.RadiusKm is { } radiusKm)
        {
            rows = rows
                .Where(a => HaversineKm(centerLat, centerLng, a.Latitude, a.Longitude) <= radiusKm)
                .ToList();
        }

        var items = await BuildDtosAsync(rows, viewerUserId, cancellationToken);
        return new ActivityListResponseDto(items, hasMore);
    }

    public async Task<ActivityListResponseDto> ListHostingAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var rows = await dbContext.Activities.AsNoTracking()
            .Where(a => a.HostUserId == userId)
            .OrderBy(a => a.StartsAt)
            .Take(50)
            .ToListAsync(cancellationToken);

        var items = await BuildDtosAsync(rows, userId, cancellationToken);
        return new ActivityListResponseDto(items, false);
    }

    public async Task<ActivityListResponseDto> ListJoinedAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var participatingIds = await dbContext.ActivityParticipations.AsNoTracking()
            .Where(p => p.UserId == userId
                && (p.Status == ActivityParticipationStatus.Approved
                    || p.Status == ActivityParticipationStatus.Requested))
            .Select(p => p.ActivityId)
            .ToListAsync(cancellationToken);

        if (participatingIds.Count == 0)
        {
            return new ActivityListResponseDto([], false);
        }

        var rows = await dbContext.Activities.AsNoTracking()
            .Where(a => participatingIds.Contains(a.Id))
            .OrderBy(a => a.StartsAt)
            .ToListAsync(cancellationToken);

        var items = await BuildDtosAsync(rows, userId, cancellationToken);
        return new ActivityListResponseDto(items, false);
    }

    public async Task<ActivityDto?> UpdateAsync(
        Guid activityId,
        string hostUserId,
        UpdateActivityRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var activity = await dbContext.Activities
            .FirstOrDefaultAsync(a => a.Id == activityId, cancellationToken);
        if (activity is null) return null;
        if (!string.Equals(activity.HostUserId, hostUserId, StringComparison.Ordinal))
        {
            throw new UnauthorizedAccessException("Only the host can update this activity.");
        }
        if (activity.Status != ActivityStatus.Published)
        {
            throw new InvalidOperationException("Only published activities can be edited.");
        }

        if (request.Title is { Length: > 0 } title) activity.Title = title.Trim();
        if (request.Description is not null) activity.Description = request.Description.Trim();
        if (request.CoverImageUrl is not null)
        {
            activity.CoverImageUrl = string.IsNullOrWhiteSpace(request.CoverImageUrl) ? null : request.CoverImageUrl.Trim();
        }
        if (request.LocationName is { Length: > 0 } locName) activity.LocationName = locName.Trim();
        if (request.LocationAddress is not null)
        {
            activity.LocationAddress = string.IsNullOrWhiteSpace(request.LocationAddress) ? null : request.LocationAddress.Trim();
        }
        if (request.Latitude.HasValue) activity.Latitude = request.Latitude.Value;
        if (request.Longitude.HasValue) activity.Longitude = request.Longitude.Value;
        if (request.City is { Length: > 0 } city)
        {
            activity.City = city.Trim();
            activity.NormalizedCity = TextNormalizer.Normalize(city);
        }
        if (request.PlaceId is not null)
        {
            activity.PlaceId = string.IsNullOrWhiteSpace(request.PlaceId) ? null : request.PlaceId.Trim();
        }
        if (request.StartsAt.HasValue)
        {
            if (request.StartsAt.Value <= DateTimeOffset.UtcNow.AddMinutes(-1))
            {
                throw new InvalidOperationException("Activity start time must be in the future.");
            }
            activity.StartsAt = request.StartsAt.Value;
            activity.ReminderSent = false; // reschedule reminder
        }
        if (request.EndsAt.HasValue) activity.EndsAt = request.EndsAt;
        if (request.ReminderMinutesBefore.HasValue) activity.ReminderMinutesBefore = request.ReminderMinutesBefore.Value;
        if (request.MaxParticipants.HasValue) activity.MaxParticipants = request.MaxParticipants;
        if (request.Visibility is { Length: > 0 } vis)
        {
            activity.Visibility = ParseEnum(vis, activity.Visibility);
        }
        if (request.JoinPolicy is { Length: > 0 } jp)
        {
            activity.JoinPolicy = ParseEnum(jp, activity.JoinPolicy);
        }
        if (request.RequiresVerification.HasValue) activity.RequiresVerification = request.RequiresVerification.Value;
        if (request.Interests is not null)
        {
            activity.Interests = request.Interests
                .Select(t => t.Trim())
                .Where(t => !string.IsNullOrEmpty(t))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Take(20)
                .ToList();
        }
        if (request.MinAge.HasValue) activity.MinAge = request.MinAge;
        if (request.MaxAge.HasValue) activity.MaxAge = request.MaxAge;
        if (request.PreferredGender is { Length: > 0 } pref) activity.PreferredGender = pref.Trim().ToLowerInvariant();
        if (request.RecurrenceRule is not null)
        {
            activity.RecurrenceRule = NormalizeRecurrenceRule(request.RecurrenceRule);
        }
        if (request.RecurrenceUntil.HasValue || request.RecurrenceRule == string.Empty)
        {
            activity.RecurrenceUntil = request.RecurrenceUntil;
        }

        activity.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        var approvedUserIds = await dbContext.ActivityParticipations.AsNoTracking()
            .Where(p => p.ActivityId == activity.Id
                && p.Status == ActivityParticipationStatus.Approved)
            .Select(p => p.UserId)
            .ToListAsync(cancellationToken);

        var recipients = approvedUserIds.Append(hostUserId).Distinct().ToList();
        await realtimeNotifier.NotifyActivityChangedAsync(
            activity.Id,
            recipients,
            "updated",
            cancellationToken);

        var hostName = (await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == hostUserId, cancellationToken))?.DisplayName ?? "Etkinlik sahibi";
        foreach (var recipientId in approvedUserIds)
        {
            _ = notificationsService.CreateAsync(
                recipientId,
                NotificationType.ActivityUpdated,
                hostName,
                $"\"{activity.Title}\" güncellendi",
                actorUserId: hostUserId,
                deepLink: $"/activities/{activity.Id}",
                relatedEntityType: "Activity",
                relatedEntityId: activity.Id.ToString(),
                cancellationToken: cancellationToken
            );
        }

        return await BuildDtoAsync(activity, hostUserId, cancellationToken);
    }

    public async Task<bool> CancelAsync(
        Guid activityId,
        string hostUserId,
        CancelActivityRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var activity = await dbContext.Activities
            .FirstOrDefaultAsync(a => a.Id == activityId, cancellationToken);
        if (activity is null) return false;
        if (!string.Equals(activity.HostUserId, hostUserId, StringComparison.Ordinal))
        {
            throw new UnauthorizedAccessException("Only the host can cancel this activity.");
        }
        if (activity.Status == ActivityStatus.Cancelled) return true;

        activity.Status = ActivityStatus.Cancelled;
        activity.CancelledAt = DateTimeOffset.UtcNow;
        activity.CancellationReason = string.IsNullOrWhiteSpace(request.Reason) ? null : request.Reason.Trim();
        activity.UpdatedAt = DateTimeOffset.UtcNow;

        var affectedUserIds = await dbContext.ActivityParticipations.AsNoTracking()
            .Where(p => p.ActivityId == activity.Id
                && (p.Status == ActivityParticipationStatus.Approved
                    || p.Status == ActivityParticipationStatus.Requested))
            .Select(p => p.UserId)
            .ToListAsync(cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);

        var recipients = affectedUserIds.Append(hostUserId).Distinct().ToList();
        await realtimeNotifier.NotifyActivityChangedAsync(
            activity.Id,
            recipients,
            "cancelled",
            cancellationToken);

        var hostName = (await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == hostUserId, cancellationToken))?.DisplayName ?? "Etkinlik sahibi";
        var body = string.IsNullOrWhiteSpace(activity.CancellationReason)
            ? $"\"{activity.Title}\" iptal edildi"
            : $"\"{activity.Title}\" iptal edildi: {activity.CancellationReason}";
        foreach (var recipientId in affectedUserIds)
        {
            _ = notificationsService.CreateAsync(
                recipientId,
                NotificationType.ActivityCancelled,
                hostName,
                body,
                actorUserId: hostUserId,
                deepLink: $"/activities/{activity.Id}",
                relatedEntityType: "Activity",
                relatedEntityId: activity.Id.ToString(),
                cancellationToken: cancellationToken
            );
        }

        return true;
    }

    public async Task<ActivityParticipationDto?> JoinAsync(
        Guid activityId,
        string userId,
        JoinActivityRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var activity = await dbContext.Activities
            .FirstOrDefaultAsync(a => a.Id == activityId, cancellationToken);
        if (activity is null) return null;
        if (activity.Status != ActivityStatus.Published)
        {
            throw new InvalidOperationException("Activity is not open to joins.");
        }
        if (string.Equals(activity.HostUserId, userId, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Host cannot join their own activity.");
        }
        if (!await CanViewAsync(activity, userId, cancellationToken))
        {
            throw new UnauthorizedAccessException("You cannot join this activity.");
        }

        var existing = await dbContext.ActivityParticipations
            .FirstOrDefaultAsync(p => p.ActivityId == activityId && p.UserId == userId, cancellationToken);

        var now = DateTimeOffset.UtcNow;

        if (existing is not null)
        {
            if (existing.Status == ActivityParticipationStatus.Cancelled
                || existing.Status == ActivityParticipationStatus.Declined)
            {
                existing.Status = activity.JoinPolicy == ActivityJoinPolicy.Open
                    ? ActivityParticipationStatus.Approved
                    : ActivityParticipationStatus.Requested;
                existing.JoinMessage = string.IsNullOrWhiteSpace(request.Message) ? null : request.Message.Trim();
                existing.RequestedAt = now;
                existing.RespondedAt = null;
                existing.CancelledAt = null;
                if (existing.Status == ActivityParticipationStatus.Approved)
                {
                    if (activity.MaxParticipants is { } cap && activity.CurrentParticipantCount >= cap)
                    {
                        throw new InvalidOperationException("Activity is full.");
                    }
                    activity.CurrentParticipantCount += 1;
                    activity.UpdatedAt = now;
                }
                await dbContext.SaveChangesAsync(cancellationToken);
                if (existing.Status == ActivityParticipationStatus.Approved)
                {
                    var chatId = await EnsureActivityChatAsync(activity, cancellationToken);
                    await EnsureChatParticipantAsync(chatId, userId, cancellationToken);
                    await badgesService.RecomputeAsync(userId, cancellationToken);
                }
                await NotifyHostOfJoinAsync(activity, userId, existing.Status, cancellationToken);
                return await BuildParticipationDtoAsync(existing, cancellationToken);
            }
            return await BuildParticipationDtoAsync(existing, cancellationToken);
        }

        if (activity.JoinPolicy == ActivityJoinPolicy.Open
            && activity.MaxParticipants is { } maxCap
            && activity.CurrentParticipantCount >= maxCap)
        {
            throw new InvalidOperationException("Activity is full.");
        }

        var participation = new ActivityParticipation
        {
            ActivityId = activityId,
            UserId = userId,
            Status = activity.JoinPolicy == ActivityJoinPolicy.Open
                ? ActivityParticipationStatus.Approved
                : ActivityParticipationStatus.Requested,
            JoinMessage = string.IsNullOrWhiteSpace(request.Message) ? null : request.Message.Trim(),
            RequestedAt = now,
        };
        dbContext.ActivityParticipations.Add(participation);

        if (participation.Status == ActivityParticipationStatus.Approved)
        {
            activity.CurrentParticipantCount += 1;
            activity.UpdatedAt = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        if (participation.Status == ActivityParticipationStatus.Approved)
        {
            var chatId = await EnsureActivityChatAsync(activity, cancellationToken);
            await EnsureChatParticipantAsync(chatId, userId, cancellationToken);
            await badgesService.RecomputeAsync(userId, cancellationToken);
        }
        await NotifyHostOfJoinAsync(activity, userId, participation.Status, cancellationToken);
        return await BuildParticipationDtoAsync(participation, cancellationToken);
    }

    public async Task<bool> LeaveAsync(
        Guid activityId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var participation = await dbContext.ActivityParticipations
            .FirstOrDefaultAsync(p => p.ActivityId == activityId && p.UserId == userId, cancellationToken);
        if (participation is null) return false;

        if (participation.Status == ActivityParticipationStatus.Cancelled) return true;

        var wasApproved = participation.Status == ActivityParticipationStatus.Approved;
        participation.Status = ActivityParticipationStatus.Cancelled;
        participation.CancelledAt = DateTimeOffset.UtcNow;

        var activity = await dbContext.Activities
            .FirstOrDefaultAsync(a => a.Id == activityId, cancellationToken);
        if (activity is not null && wasApproved && activity.CurrentParticipantCount > 0)
        {
            activity.CurrentParticipantCount -= 1;
            activity.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        if (activity is not null)
        {
            if (wasApproved)
            {
                var chatId = await GetActivityChatIdAsync(activity.Id, cancellationToken);
                if (chatId is { } id)
                {
                    await RemoveChatParticipantAsync(id, userId, cancellationToken);
                }
            }
            await realtimeNotifier.NotifyActivityChangedAsync(
                activity.Id,
                new[] { activity.HostUserId, userId },
                "participants",
                cancellationToken);
        }

        return true;
    }

    public async Task<ActivityParticipationDto?> RespondJoinAsync(
        Guid activityId,
        Guid participationId,
        string hostUserId,
        RespondJoinRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var activity = await dbContext.Activities
            .FirstOrDefaultAsync(a => a.Id == activityId, cancellationToken);
        if (activity is null) return null;
        if (!string.Equals(activity.HostUserId, hostUserId, StringComparison.Ordinal))
        {
            throw new UnauthorizedAccessException("Only the host can respond to join requests.");
        }

        var participation = await dbContext.ActivityParticipations
            .FirstOrDefaultAsync(p => p.Id == participationId && p.ActivityId == activityId, cancellationToken);
        if (participation is null) return null;
        if (participation.Status != ActivityParticipationStatus.Requested)
        {
            return await BuildParticipationDtoAsync(participation, cancellationToken);
        }

        var now = DateTimeOffset.UtcNow;
        var decision = request.Decision?.Trim().ToLowerInvariant();

        if (decision == "approve")
        {
            if (activity.MaxParticipants is { } cap && activity.CurrentParticipantCount >= cap)
            {
                throw new InvalidOperationException("Activity is already full.");
            }
            participation.Status = ActivityParticipationStatus.Approved;
            activity.CurrentParticipantCount += 1;
            activity.UpdatedAt = now;
        }
        else if (decision == "decline")
        {
            participation.Status = ActivityParticipationStatus.Declined;
        }
        else
        {
            throw new InvalidOperationException("Invalid decision. Use 'approve' or 'decline'.");
        }

        participation.RespondedAt = now;
        participation.ResponseNote = string.IsNullOrWhiteSpace(request.ResponseNote) ? null : request.ResponseNote.Trim();
        await dbContext.SaveChangesAsync(cancellationToken);

        if (participation.Status == ActivityParticipationStatus.Approved)
        {
            var chatId = await EnsureActivityChatAsync(activity, cancellationToken);
            await EnsureChatParticipantAsync(chatId, participation.UserId, cancellationToken);
            await badgesService.RecomputeAsync(participation.UserId, cancellationToken);
        }

        await realtimeNotifier.NotifyActivityChangedAsync(
            activity.Id,
            new[] { activity.HostUserId, participation.UserId },
            "participants",
            cancellationToken);

        var hostName = (await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == hostUserId, cancellationToken))?.DisplayName ?? "Etkinlik sahibi";
        var notifType = participation.Status == ActivityParticipationStatus.Approved
            ? NotificationType.ActivityJoinAccepted
            : NotificationType.ActivityJoinDeclined;
        var body = participation.Status == ActivityParticipationStatus.Approved
            ? $"\"{activity.Title}\" katılımın onaylandı 🎉"
            : $"\"{activity.Title}\" için katılımın bu sefer kabul edilmedi";
        _ = notificationsService.CreateAsync(
            participation.UserId,
            notifType,
            hostName,
            body,
            actorUserId: hostUserId,
            deepLink: $"/activities/{activity.Id}",
            relatedEntityType: "Activity",
            relatedEntityId: activity.Id.ToString(),
            cancellationToken: cancellationToken
        );

        return await BuildParticipationDtoAsync(participation, cancellationToken);
    }

    public async Task<ActivityParticipationListDto> ListParticipantsAsync(
        Guid activityId,
        string viewerUserId,
        CancellationToken cancellationToken = default
    )
    {
        var activity = await dbContext.Activities.AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == activityId, cancellationToken);
        if (activity is null) return new ActivityParticipationListDto([]);

        var isHost = string.Equals(activity.HostUserId, viewerUserId, StringComparison.Ordinal);
        if (!isHost && !await CanViewAsync(activity, viewerUserId, cancellationToken))
        {
            return new ActivityParticipationListDto([]);
        }

        var rows = await dbContext.ActivityParticipations.AsNoTracking()
            .Where(p => p.ActivityId == activityId
                && (isHost
                    ? p.Status != ActivityParticipationStatus.Cancelled
                    : p.Status == ActivityParticipationStatus.Approved))
            .OrderBy(p => p.RequestedAt)
            .ToListAsync(cancellationToken);

        var userIds = rows.Select(r => r.UserId).Distinct().ToList();
        var users = userIds.Count == 0
            ? new Dictionary<string, UserSummaryDto>()
            : (await dbContext.Users.AsNoTracking()
                    .Where(u => userIds.Contains(u.Id))
                    .ToListAsync(cancellationToken))
                .ToDictionary(u => u.Id, u => u.ToSummaryDto());

        var items = rows
            .Where(r => users.ContainsKey(r.UserId))
            .Select(r => MapParticipation(r, users[r.UserId]))
            .ToList();
        return new ActivityParticipationListDto(items);
    }

    // ── helpers ──

    private async Task NotifyHostOfJoinAsync(
        Activity activity,
        string joinerUserId,
        ActivityParticipationStatus status,
        CancellationToken cancellationToken
    )
    {
        await realtimeNotifier.NotifyActivityChangedAsync(
            activity.Id,
            new[] { activity.HostUserId, joinerUserId },
            "participants",
            cancellationToken);

        if (status != ActivityParticipationStatus.Requested
            && status != ActivityParticipationStatus.Approved)
        {
            return;
        }

        var joiner = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == joinerUserId, cancellationToken);
        var joinerName = joiner?.DisplayName ?? "Birisi";
        var (notifType, body) = status == ActivityParticipationStatus.Requested
            ? (NotificationType.ActivityJoinRequested, $"\"{activity.Title}\" etkinliğine katılmak istiyor")
            : (NotificationType.ActivityNewParticipant, $"\"{activity.Title}\" etkinliğine katıldı 🎉");
        var deepLink = status == ActivityParticipationStatus.Requested
            ? $"/activities/{activity.Id}/participants"
            : $"/activities/{activity.Id}";
        _ = notificationsService.CreateAsync(
            activity.HostUserId,
            notifType,
            joinerName,
            body,
            actorUserId: joinerUserId,
            deepLink: deepLink,
            relatedEntityType: "Activity",
            relatedEntityId: activity.Id.ToString(),
            cancellationToken: cancellationToken
        );
    }

    private async Task<bool> CanViewAsync(
        Activity activity,
        string viewerUserId,
        CancellationToken cancellationToken
    )
    {
        if (string.Equals(activity.HostUserId, viewerUserId, StringComparison.Ordinal))
        {
            return true;
        }

        // Block: host blocked viewer or viewer blocked host => hidden
        var blocked = await dbContext.BlockedUsers.AsNoTracking()
            .AnyAsync(b =>
                (b.UserId == activity.HostUserId && b.BlockedUserId == viewerUserId)
                || (b.UserId == viewerUserId && b.BlockedUserId == activity.HostUserId),
                cancellationToken);
        if (blocked) return false;

        switch (activity.Visibility)
        {
            case ActivityVisibility.Public:
                return true;
            case ActivityVisibility.Friends:
                return await dbContext.Friendships.AsNoTracking()
                    .AnyAsync(f =>
                        (f.UserAId == activity.HostUserId && f.UserBId == viewerUserId)
                        || (f.UserBId == activity.HostUserId && f.UserAId == viewerUserId),
                        cancellationToken);
            case ActivityVisibility.MutualMatches:
                return await dbContext.Matches.AsNoTracking()
                    .AnyAsync(m =>
                        m.Status == MatchStatus.Accepted
                        && ((m.UserId1 == activity.HostUserId && m.UserId2 == viewerUserId)
                            || (m.UserId1 == viewerUserId && m.UserId2 == activity.HostUserId)),
                        cancellationToken);
            case ActivityVisibility.InviteOnly:
                return await dbContext.ActivityParticipations.AsNoTracking()
                    .AnyAsync(p => p.ActivityId == activity.Id && p.UserId == viewerUserId, cancellationToken);
        }
        return false;
    }

    private async Task<IReadOnlyList<ActivityDto>> BuildDtosAsync(
        IReadOnlyList<Activity> rows,
        string viewerUserId,
        CancellationToken cancellationToken
    )
    {
        if (rows.Count == 0) return [];

        var hostIds = rows.Select(a => a.HostUserId).Distinct().ToList();
        var activityIds = rows.Select(a => a.Id).ToList();

        var hosts = (await dbContext.Users.AsNoTracking()
                .Where(u => hostIds.Contains(u.Id))
                .ToListAsync(cancellationToken))
            .ToDictionary(u => u.Id, u => u.ToSummaryDto());

        var viewerParticipations = (await dbContext.ActivityParticipations.AsNoTracking()
                .Where(p => activityIds.Contains(p.ActivityId) && p.UserId == viewerUserId)
                .ToListAsync(cancellationToken))
            .ToDictionary(p => p.ActivityId, p => p.Status);

        var sampleParticipants = await dbContext.ActivityParticipations.AsNoTracking()
            .Where(p => activityIds.Contains(p.ActivityId)
                && p.Status == ActivityParticipationStatus.Approved)
            .OrderBy(p => p.RequestedAt)
            .Select(p => new { p.ActivityId, p.UserId })
            .ToListAsync(cancellationToken);

        var sampleByActivity = sampleParticipants
            .GroupBy(p => p.ActivityId)
            .ToDictionary(
                g => g.Key,
                g => g.Take(SampleParticipantLimit).Select(x => x.UserId).ToList()
            );

        var sampleUserIds = sampleByActivity.Values.SelectMany(v => v).Distinct().ToList();
        var sampleUsers = sampleUserIds.Count == 0
            ? new Dictionary<string, UserSummaryDto>()
            : (await dbContext.Users.AsNoTracking()
                    .Where(u => sampleUserIds.Contains(u.Id))
                    .ToListAsync(cancellationToken))
                .ToDictionary(u => u.Id, u => u.ToSummaryDto());

        var dtos = new List<ActivityDto>(rows.Count);
        foreach (var activity in rows)
        {
            if (!hosts.TryGetValue(activity.HostUserId, out var host))
            {
                continue;
            }

            var visibilityOk = await CanViewAsync(activity, viewerUserId, cancellationToken);
            if (!visibilityOk) continue;

            string? viewerStatus = null;
            if (string.Equals(activity.HostUserId, viewerUserId, StringComparison.Ordinal))
            {
                viewerStatus = "host";
            }
            else if (viewerParticipations.TryGetValue(activity.Id, out var status))
            {
                viewerStatus = status.ToString().ToLowerInvariant();
            }

            var sampleIds = sampleByActivity.GetValueOrDefault(activity.Id) ?? [];
            var samples = sampleIds
                .Select(id => sampleUsers.GetValueOrDefault(id))
                .Where(u => u is not null)
                .Cast<UserSummaryDto>()
                .ToList();

            dtos.Add(MapActivity(activity, host, viewerStatus, samples));
        }
        return dtos;
    }

    private async Task<ActivityDto?> BuildDtoAsync(
        Activity activity,
        string viewerUserId,
        CancellationToken cancellationToken
    )
    {
        var dtos = await BuildDtosAsync(new[] { activity }, viewerUserId, cancellationToken);
        return dtos.Count == 0 ? null : dtos[0];
    }

    private async Task<ActivityParticipationDto?> BuildParticipationDtoAsync(
        ActivityParticipation participation,
        CancellationToken cancellationToken
    )
    {
        var user = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == participation.UserId, cancellationToken);
        if (user is null) return null;
        return MapParticipation(participation, user.ToSummaryDto());
    }

    private static ActivityDto MapActivity(
        Activity activity,
        UserSummaryDto host,
        string? viewerStatus,
        IReadOnlyList<UserSummaryDto> samples
    ) =>
        new(
            activity.Id,
            host,
            activity.Title,
            activity.Description,
            activity.Category.ToString(),
            activity.Mode,
            activity.CoverImageUrl,
            activity.LocationName,
            activity.LocationAddress,
            activity.Latitude,
            activity.Longitude,
            activity.City,
            activity.PlaceId,
            activity.StartsAt,
            activity.EndsAt,
            activity.MaxParticipants,
            activity.CurrentParticipantCount,
            activity.Visibility.ToString(),
            activity.JoinPolicy.ToString(),
            activity.RequiresVerification,
            activity.Interests,
            activity.MinAge,
            activity.MaxAge,
            activity.PreferredGender,
            activity.Status.ToString(),
            activity.CancellationReason,
            activity.CreatedAt,
            activity.UpdatedAt,
            viewerStatus,
            viewerStatus == "host",
            samples,
            activity.RecurrenceRule ?? string.Empty,
            activity.RecurrenceUntil
        );

    private static string NormalizeRecurrenceRule(string? raw)
    {
        var trimmed = raw?.Trim().ToLowerInvariant() ?? string.Empty;
        return trimmed switch
        {
            "weekly" or "biweekly" or "monthly" => trimmed,
            _ => string.Empty,
        };
    }

    private static ActivityParticipationDto MapParticipation(
        ActivityParticipation participation,
        UserSummaryDto user
    ) =>
        new(
            participation.Id,
            participation.ActivityId,
            user,
            participation.Status.ToString().ToLowerInvariant(),
            participation.JoinMessage,
            participation.ResponseNote,
            participation.RequestedAt,
            participation.RespondedAt
        );

    private static T ParseEnum<T>(string? value, T fallback) where T : struct, Enum
    {
        if (string.IsNullOrWhiteSpace(value)) return fallback;
        return Enum.TryParse<T>(value, ignoreCase: true, out var parsed) ? parsed : fallback;
    }

    private static (DateTimeOffset? from, DateTimeOffset? to) ResolveWhenWindow(string when, DateTimeOffset now)
    {
        var today = new DateTimeOffset(now.Year, now.Month, now.Day, 0, 0, 0, now.Offset);
        return when.Trim().ToLowerInvariant() switch
        {
            "today" => (today, today.AddDays(1)),
            "tomorrow" => (today.AddDays(1), today.AddDays(2)),
            "this-week" => (today, today.AddDays(7)),
            "weekend" => ResolveWeekendWindow(today),
            _ => (null, null),
        };
    }

    private static (DateTimeOffset? from, DateTimeOffset? to) ResolveWeekendWindow(DateTimeOffset today)
    {
        var dayOfWeek = (int)today.DayOfWeek;
        var daysUntilSaturday = (6 - dayOfWeek + 7) % 7;
        var saturday = today.AddDays(daysUntilSaturday);
        return (saturday, saturday.AddDays(2));
    }

    private static double HaversineKm(double lat1, double lng1, double lat2, double lng2)
    {
        const double earthRadius = 6371.0;
        var dLat = ToRadians(lat2 - lat1);
        var dLng = ToRadians(lng2 - lng1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
            + Math.Cos(ToRadians(lat1)) * Math.Cos(ToRadians(lat2))
            * Math.Sin(dLng / 2) * Math.Sin(dLng / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return earthRadius * c;
    }

    private static double ToRadians(double degrees) => degrees * Math.PI / 180.0;

    public async Task<ChatThreadDto?> GetOrCreateGroupChatAsync(
        Guid activityId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var activity = await dbContext.Activities
            .FirstOrDefaultAsync(a => a.Id == activityId, cancellationToken);
        if (activity is null) return null;

        var isHost = string.Equals(activity.HostUserId, userId, StringComparison.Ordinal);
        if (!isHost)
        {
            var participation = await dbContext.ActivityParticipations.AsNoTracking()
                .FirstOrDefaultAsync(
                    p => p.ActivityId == activityId
                        && p.UserId == userId
                        && p.Status == ActivityParticipationStatus.Approved,
                    cancellationToken);
            if (participation is null) return null;
        }

        var chatId = await EnsureActivityChatAsync(activity, cancellationToken);
        await EnsureChatParticipantAsync(chatId, userId, cancellationToken);

        return await chatsService.GetChatAsync(chatId, userId, cancellationToken);
    }

    private async Task<Guid> EnsureActivityChatAsync(
        Activity activity,
        CancellationToken cancellationToken
    )
    {
        var existing = await dbContext.Chats
            .FirstOrDefaultAsync(c => c.ActivityId == activity.Id && c.Kind == "activity", cancellationToken);
        if (existing is not null)
        {
            if (!string.Equals(existing.Title, activity.Title, StringComparison.Ordinal))
            {
                existing.Title = activity.Title;
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            await EnsureChatParticipantAsync(existing.Id, activity.HostUserId, cancellationToken);
            return existing.Id;
        }

        var now = DateTimeOffset.UtcNow;
        var chat = new ChatThread
        {
            CreatedByUserId = activity.HostUserId,
            CreatedAt = now,
            LastMessageTime = now,
            IsTemporary = false,
            IsFriendChat = false,
            DirectMessageKey = null,
            Kind = "activity",
            ActivityId = activity.Id,
            Title = activity.Title,
        };
        dbContext.Chats.Add(chat);
        dbContext.ChatParticipants.Add(new ChatParticipant
        {
            ChatId = chat.Id,
            UserId = activity.HostUserId,
            JoinedAt = now,
            LastReadAt = now,
        });
        await dbContext.SaveChangesAsync(cancellationToken);
        return chat.Id;
    }

    private async Task<Guid?> GetActivityChatIdAsync(
        Guid activityId,
        CancellationToken cancellationToken
    )
    {
        var chat = await dbContext.Chats.AsNoTracking()
            .FirstOrDefaultAsync(c => c.ActivityId == activityId && c.Kind == "activity", cancellationToken);
        return chat?.Id;
    }

    private async Task EnsureChatParticipantAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken
    )
    {
        var participant = await dbContext.ChatParticipants
            .FirstOrDefaultAsync(p => p.ChatId == chatId && p.UserId == userId, cancellationToken);
        var now = DateTimeOffset.UtcNow;
        if (participant is null)
        {
            dbContext.ChatParticipants.Add(new ChatParticipant
            {
                ChatId = chatId,
                UserId = userId,
                JoinedAt = now,
                LastReadAt = now,
            });
            await dbContext.SaveChangesAsync(cancellationToken);
            return;
        }

        if (participant.DeletedAt is not null)
        {
            participant.DeletedAt = null;
            participant.JoinedAt = now;
            participant.LastReadAt = now;
            participant.UnreadCount = 0;
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    private async Task RemoveChatParticipantAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken
    )
    {
        var participant = await dbContext.ChatParticipants
            .FirstOrDefaultAsync(p => p.ChatId == chatId && p.UserId == userId, cancellationToken);
        if (participant is null || participant.DeletedAt is not null) return;
        participant.DeletedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    // ── Ratings ──

    public async Task<ActivityRatingDto?> CreateRatingAsync(
        Guid activityId,
        string raterUserId,
        CreateActivityRatingRequest request,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(raterUserId))
        {
            throw new ArgumentException("Rater id required.", nameof(raterUserId));
        }
        if (string.IsNullOrWhiteSpace(request.RatedUserId))
        {
            throw new InvalidOperationException("RatedUserId is required.");
        }
        if (string.Equals(raterUserId, request.RatedUserId, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Self-rating is not allowed.");
        }
        if (request.Score < 1 || request.Score > 5)
        {
            throw new InvalidOperationException("Score must be 1..5.");
        }

        var activity = await dbContext.Activities
            .FirstOrDefaultAsync(a => a.Id == activityId, cancellationToken);
        if (activity is null) return null;

        var startedAlready = activity.StartsAt <= DateTimeOffset.UtcNow;
        if (!startedAlready)
        {
            throw new InvalidOperationException("Rating is only available after the activity starts.");
        }

        var raterIsHost = string.Equals(activity.HostUserId, raterUserId, StringComparison.Ordinal);
        var ratedIsHost = string.Equals(activity.HostUserId, request.RatedUserId, StringComparison.Ordinal);

        if (!raterIsHost)
        {
            var raterApproved = await dbContext.ActivityParticipations.AsNoTracking()
                .AnyAsync(p => p.ActivityId == activityId
                    && p.UserId == raterUserId
                    && p.Status == ActivityParticipationStatus.Approved,
                    cancellationToken);
            if (!raterApproved)
            {
                throw new UnauthorizedAccessException("Only host or approved participants can rate.");
            }
        }

        if (!ratedIsHost)
        {
            var ratedApproved = await dbContext.ActivityParticipations.AsNoTracking()
                .AnyAsync(p => p.ActivityId == activityId
                    && p.UserId == request.RatedUserId
                    && p.Status == ActivityParticipationStatus.Approved,
                    cancellationToken);
            if (!ratedApproved)
            {
                throw new InvalidOperationException("Rated user is not part of this activity.");
            }
        }

        var existing = await dbContext.ActivityRatings
            .FirstOrDefaultAsync(r => r.ActivityId == activityId
                && r.RaterUserId == raterUserId
                && r.RatedUserId == request.RatedUserId,
                cancellationToken);

        if (existing is null)
        {
            existing = new ActivityRating
            {
                ActivityId = activityId,
                RaterUserId = raterUserId,
                RatedUserId = request.RatedUserId,
                Score = request.Score,
                Comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim(),
                CreatedAt = DateTimeOffset.UtcNow,
            };
            dbContext.ActivityRatings.Add(existing);
        }
        else
        {
            existing.Score = request.Score;
            existing.Comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();
            existing.CreatedAt = DateTimeOffset.UtcNow;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await RecomputeUserRatingAggregateAsync(request.RatedUserId, cancellationToken);

        // Yıldız Profil rozeti rated kullanıcının yeni ortalama/sayısına göre güncellenir.
        await badgesService.RecomputeAsync(request.RatedUserId, cancellationToken);

        var rater = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == raterUserId, cancellationToken);
        var rated = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == request.RatedUserId, cancellationToken);
        if (rater is null || rated is null) return null;

        return MapRating(existing, rater.ToSummaryDto(), rated.ToSummaryDto());
    }

    public async Task<ActivityRatingListDto> ListActivityRatingsAsync(
        Guid activityId,
        string viewerUserId,
        CancellationToken cancellationToken = default
    )
    {
        var ratings = await dbContext.ActivityRatings.AsNoTracking()
            .Where(r => r.ActivityId == activityId)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync(cancellationToken);

        if (ratings.Count == 0)
        {
            return new ActivityRatingListDto(Array.Empty<ActivityRatingDto>(), 0, 0);
        }

        var userIds = ratings.SelectMany(r => new[] { r.RaterUserId, r.RatedUserId })
            .Distinct()
            .ToList();
        var users = (await dbContext.Users.AsNoTracking()
                .Where(u => userIds.Contains(u.Id))
                .ToListAsync(cancellationToken))
            .ToDictionary(u => u.Id, u => u.ToSummaryDto());

        var items = new List<ActivityRatingDto>(ratings.Count);
        foreach (var r in ratings)
        {
            if (!users.TryGetValue(r.RaterUserId, out var rater)) continue;
            if (!users.TryGetValue(r.RatedUserId, out var rated)) continue;
            items.Add(MapRating(r, rater, rated));
        }

        var avg = items.Count == 0 ? 0 : items.Average(i => (double)i.Score);
        return new ActivityRatingListDto(items, Math.Round(avg, 2), items.Count);
    }

    public async Task<ActivityRatingListDto> ListUserRatingsAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var ratings = await dbContext.ActivityRatings.AsNoTracking()
            .Where(r => r.RatedUserId == userId)
            .OrderByDescending(r => r.CreatedAt)
            .Take(50)
            .ToListAsync(cancellationToken);

        if (ratings.Count == 0)
        {
            return new ActivityRatingListDto(Array.Empty<ActivityRatingDto>(), 0, 0);
        }

        var userIds = ratings.SelectMany(r => new[] { r.RaterUserId, r.RatedUserId })
            .Distinct()
            .ToList();
        var users = (await dbContext.Users.AsNoTracking()
                .Where(u => userIds.Contains(u.Id))
                .ToListAsync(cancellationToken))
            .ToDictionary(u => u.Id, u => u.ToSummaryDto());

        var items = new List<ActivityRatingDto>(ratings.Count);
        foreach (var r in ratings)
        {
            if (!users.TryGetValue(r.RaterUserId, out var rater)) continue;
            if (!users.TryGetValue(r.RatedUserId, out var rated)) continue;
            items.Add(MapRating(r, rater, rated));
        }

        var ratedUserSummary = users.GetValueOrDefault(userId);
        var avg = ratedUserSummary?.ActivityRatingAverage ?? 0;
        var count = ratedUserSummary?.ActivityRatingCount ?? items.Count;
        return new ActivityRatingListDto(items, Math.Round(avg, 2), count);
    }

    public async Task<PendingRatingListDto> ListPendingRatingsAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return new PendingRatingListDto(Array.Empty<PendingRatingDto>());
        }

        var now = DateTimeOffset.UtcNow;
        var horizon = now.AddDays(-30);

        var hostedActivities = await dbContext.Activities.AsNoTracking()
            .Where(a => a.HostUserId == userId
                && a.StartsAt <= now
                && a.StartsAt >= horizon
                && a.Status != ActivityStatus.Cancelled)
            .ToListAsync(cancellationToken);

        var joinedActivityIds = await dbContext.ActivityParticipations.AsNoTracking()
            .Where(p => p.UserId == userId
                && p.Status == ActivityParticipationStatus.Approved)
            .Select(p => p.ActivityId)
            .ToListAsync(cancellationToken);

        var joinedActivities = await dbContext.Activities.AsNoTracking()
            .Where(a => joinedActivityIds.Contains(a.Id)
                && a.StartsAt <= now
                && a.StartsAt >= horizon
                && a.Status != ActivityStatus.Cancelled)
            .ToListAsync(cancellationToken);

        var allActivities = hostedActivities
            .Concat(joinedActivities)
            .GroupBy(a => a.Id)
            .Select(g => g.First())
            .OrderByDescending(a => a.StartsAt)
            .ToList();

        if (allActivities.Count == 0)
        {
            return new PendingRatingListDto(Array.Empty<PendingRatingDto>());
        }

        var ids = allActivities.Select(a => a.Id).ToList();

        var participantsByActivity = (await dbContext.ActivityParticipations.AsNoTracking()
                .Where(p => ids.Contains(p.ActivityId)
                    && p.Status == ActivityParticipationStatus.Approved)
                .Select(p => new { p.ActivityId, p.UserId })
                .ToListAsync(cancellationToken))
            .GroupBy(x => x.ActivityId)
            .ToDictionary(g => g.Key, g => g.Select(x => x.UserId).ToList());

        var existingRatings = (await dbContext.ActivityRatings.AsNoTracking()
                .Where(r => ids.Contains(r.ActivityId) && r.RaterUserId == userId)
                .Select(r => new { r.ActivityId, r.RatedUserId })
                .ToListAsync(cancellationToken))
            .GroupBy(x => x.ActivityId)
            .ToDictionary(g => g.Key, g => g.Select(x => x.RatedUserId).ToHashSet());

        var dtos = await BuildDtosAsync(allActivities, userId, cancellationToken);
        var dtoById = dtos.ToDictionary(d => d.Id);

        var allRateableUserIds = new HashSet<string>();
        foreach (var act in allActivities)
        {
            allRateableUserIds.Add(act.HostUserId);
            if (participantsByActivity.TryGetValue(act.Id, out var pids))
            {
                foreach (var pid in pids) allRateableUserIds.Add(pid);
            }
        }
        allRateableUserIds.Remove(userId);

        var users = allRateableUserIds.Count == 0
            ? new Dictionary<string, UserSummaryDto>()
            : (await dbContext.Users.AsNoTracking()
                    .Where(u => allRateableUserIds.Contains(u.Id))
                    .ToListAsync(cancellationToken))
                .ToDictionary(u => u.Id, u => u.ToSummaryDto());

        var pending = new List<PendingRatingDto>();
        foreach (var act in allActivities)
        {
            if (!dtoById.TryGetValue(act.Id, out var actDto)) continue;

            var counterparts = new List<string>();
            if (!string.Equals(act.HostUserId, userId, StringComparison.Ordinal))
            {
                counterparts.Add(act.HostUserId);
            }
            if (participantsByActivity.TryGetValue(act.Id, out var pids))
            {
                foreach (var pid in pids)
                {
                    if (!string.Equals(pid, userId, StringComparison.Ordinal))
                    {
                        counterparts.Add(pid);
                    }
                }
            }
            counterparts = counterparts.Distinct().ToList();

            var alreadyRated = existingRatings.GetValueOrDefault(act.Id) ?? new HashSet<string>();
            var rateable = counterparts
                .Where(c => !alreadyRated.Contains(c))
                .Select(c => users.GetValueOrDefault(c))
                .Where(u => u is not null)
                .Cast<UserSummaryDto>()
                .ToList();

            if (rateable.Count == 0) continue;
            pending.Add(new PendingRatingDto(actDto, rateable));
        }

        return new PendingRatingListDto(pending);
    }

    private async Task RecomputeUserRatingAggregateAsync(
        string userId,
        CancellationToken cancellationToken
    )
    {
        var stats = await dbContext.ActivityRatings.AsNoTracking()
            .Where(r => r.RatedUserId == userId)
            .GroupBy(r => r.RatedUserId)
            .Select(g => new
            {
                Avg = g.Average(x => (double)x.Score),
                Count = g.Count(),
            })
            .FirstOrDefaultAsync(cancellationToken);

        var user = await dbContext.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null) return;

        user.ActivityRatingAverage = stats is null ? 0 : Math.Round(stats.Avg, 2);
        user.ActivityRatingCount = stats?.Count ?? 0;
        user.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static ActivityRatingDto MapRating(
        ActivityRating rating,
        UserSummaryDto rater,
        UserSummaryDto rated
    ) =>
        new(
            rating.Id,
            rating.ActivityId,
            rater,
            rated,
            rating.Score,
            rating.Comment,
            rating.CreatedAt
        );
}
