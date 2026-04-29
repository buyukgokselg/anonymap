using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Api.Extensions;

namespace PulseCity.Api.Hubs;

[Authorize]
public sealed class PulsePresenceHub(IPresenceService presenceService) : Hub
{
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

        await Clients.Caller.SendAsync("presenceUpdated", new
        {
            userId,
            latitude,
            longitude,
            mode = mode.Trim(),
            shareProfile,
            isSignalActive,
            city = city.Trim(),
            updatedAt = DateTimeOffset.UtcNow,
        });
    }
}
