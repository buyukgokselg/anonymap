using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IPresenceService
{
    Task UpdatePresenceAsync(
        string userId,
        UpdatePresenceRequest request,
        CancellationToken cancellationToken = default
    );

    Task UpdateOnlineStatusAsync(
        string userId,
        UpdateOnlineStatusRequest request,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<NearbyUserDto>> GetNearbyUsersAsync(
        string currentUserId,
        NearbyUsersRequest request,
        CancellationToken cancellationToken = default
    );

    Task<LobbySnapshotDto> GetLobbySnapshotAsync(
        CancellationToken cancellationToken = default
    );
}
