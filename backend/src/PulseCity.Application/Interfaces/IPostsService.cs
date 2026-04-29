using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IPostsService
{
    Task<IReadOnlyList<PostFeedItemDto>> GetFeedAsync(
        string? currentUserId,
        int take,
        string? vibeTag = null,
        string? type = null,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<PostFeedItemDto>> GetShortsFeedAsync(
        string? currentUserId,
        int take,
        string scope,
        double? latitude = null,
        double? longitude = null,
        double? radiusKm = null,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<PostFeedItemDto>> GetUserPostsAsync(
        string userId,
        string? currentUserId,
        string? type = null,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<PostFeedItemDto>> GetSavedPostsAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<PostFeedItemDto> CreatePostAsync(
        string userId,
        CreatePostRequest request,
        CancellationToken cancellationToken = default
    );

    Task<PostFeedItemDto?> UpdatePostAsync(
        Guid postId,
        string userId,
        UpdatePostRequest request,
        CancellationToken cancellationToken = default
    );

    Task<PostInteractionDto> ToggleLikeAsync(
        Guid postId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<PostCommentDto> AddCommentAsync(
        Guid postId,
        string userId,
        AddPostCommentRequest request,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<PostCommentDto>> GetCommentsAsync(
        Guid postId,
        string? currentUserId,
        int skip = 0,
        int take = 50,
        CancellationToken cancellationToken = default
    );

    Task<PostCommentDto?> UpdateCommentAsync(
        Guid postId,
        Guid commentId,
        string userId,
        UpdatePostCommentRequest request,
        CancellationToken cancellationToken = default
    );

    Task<bool> DeleteCommentAsync(
        Guid postId,
        Guid commentId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<PostSaveDto> ToggleSaveAsync(
        Guid postId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<bool> DeletePostAsync(
        Guid postId,
        string userId,
        CancellationToken cancellationToken = default
    );
}
