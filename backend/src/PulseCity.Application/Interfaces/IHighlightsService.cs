using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IHighlightsService
{
    Task<HighlightDto> CreateHighlightAsync(
        string userId,
        CreateHighlightRequest request,
        CancellationToken cancellationToken = default
    );

    Task<HighlightDto> CreateStoryAsync(
        string userId,
        CreateHighlightRequest request,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<HighlightDto>> GetHighlightsByUserAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<HighlightDto>> GetActiveStoriesByUserAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    );

    Task<bool> DeleteHighlightAsync(
        string userId,
        Guid highlightId,
        CancellationToken cancellationToken = default
    );

    Task<bool> DeleteStoryAsync(
        string userId,
        Guid storyId,
        CancellationToken cancellationToken = default
    );

    Task RecordStoryViewAsync(
        Guid storyId,
        string viewerUserId,
        CancellationToken cancellationToken = default
    );
}
