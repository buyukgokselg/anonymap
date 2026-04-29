using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IMatchesService
{
    Task<MatchDto> CreateAsync(
        string userId,
        CreateMatchRequest request,
        CancellationToken cancellationToken = default
    );

    Task<bool> RespondAsync(
        Guid matchId,
        string userId,
        RespondToMatchRequest request,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<MatchDto>> GetPendingIncomingAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<MatchDto>> GetAllMatchesAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Returns the pending matches where <paramref name="userId"/> is the recipient
    /// (i.e. people who have "liked" the caller and are awaiting their response).
    /// Blocked users are filtered out.
    /// </summary>
    Task<LikesMeResponseDto> GetLikesMeAsync(
        string userId,
        LikesMeQuery query,
        CancellationToken cancellationToken = default
    );
}
