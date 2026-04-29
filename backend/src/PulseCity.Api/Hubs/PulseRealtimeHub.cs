using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Application.Realtime;
using PulseCity.Infrastructure.Data;
using System.Collections.Concurrent;

namespace PulseCity.Api.Hubs;

[Authorize]
public sealed class PulseRealtimeHub(
    PulseCityDbContext dbContext,
    IPresenceService presenceService
) : Hub
{
    private static readonly ConcurrentDictionary<string, string> PresenceGroups = new();

    public override async Task OnConnectedAsync()
    {
        var userId = Context.User?.GetRequiredUserId()
            ?? throw new HubException("Authenticated user id is missing.");
        await Groups.AddToGroupAsync(Context.ConnectionId, RealtimeGroups.User(userId));
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (PresenceGroups.TryRemove(Context.ConnectionId, out var presenceGroup))
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, presenceGroup);
        }

        await base.OnDisconnectedAsync(exception);
    }

    public async Task SubscribePresence(string city)
    {
        var nextGroup = RealtimeGroups.Presence(city);
        if (PresenceGroups.TryGetValue(Context.ConnectionId, out var previousGroup)
            && !string.Equals(previousGroup, nextGroup, StringComparison.Ordinal))
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, previousGroup);
        }

        PresenceGroups[Context.ConnectionId] = nextGroup;
        await Groups.AddToGroupAsync(Context.ConnectionId, nextGroup);
        await Clients.Caller.SendAsync("presenceSubscribed", new { city = city.Trim() });
    }

    public async Task UnsubscribePresence(string city)
    {
        var group = RealtimeGroups.Presence(city);
        PresenceGroups.TryRemove(Context.ConnectionId, out _);
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, group);
    }

    public async Task SubscribeFeed()
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "feed");
    }

    public async Task SubscribeUser(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return;
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, RealtimeGroups.User(userId));
    }

    public async Task UnsubscribeUser(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return;
        }

        await Groups.RemoveFromGroupAsync(Context.ConnectionId, RealtimeGroups.User(userId));
    }

    public async Task SubscribeChat(Guid chatId)
    {
        var userId = Context.User?.GetRequiredUserId()
            ?? throw new HubException("Authenticated user id is missing.");
        var isParticipant = await dbContext.ChatParticipants.AsNoTracking()
            .AnyAsync(entry => entry.ChatId == chatId && entry.UserId == userId);
        if (!isParticipant)
        {
            throw new HubException("Chat access denied.");
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, RealtimeGroups.Chat(chatId));
    }

    public async Task UnsubscribeChat(Guid chatId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, RealtimeGroups.Chat(chatId));
    }

    public async Task UpdatePresence(
        double latitude,
        double longitude,
        string mode,
        bool shareProfile,
        bool isSignalActive,
        string city
    )
    {
        var userId = Context.User?.GetRequiredUserId()
            ?? throw new HubException("Authenticated user id is missing.");

        await presenceService.UpdatePresenceAsync(
            userId,
            new UpdatePresenceRequest
            {
                Latitude = latitude,
                Longitude = longitude,
                Mode = mode,
                ShareProfile = shareProfile,
                IsSignalActive = isSignalActive,
                IsOnline = true,
                City = city,
            }
        );

        await Clients.Caller.SendAsync(
            "presenceUpdated",
            new
            {
                userId,
                latitude,
                longitude,
                mode,
                shareProfile,
                isSignalActive,
                city,
                updatedAt = DateTimeOffset.UtcNow,
            }
        );
    }
}
