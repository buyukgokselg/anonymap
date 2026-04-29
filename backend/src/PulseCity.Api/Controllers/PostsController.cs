using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class PostsController(IPostsService postsService) : ControllerBase
{
    [HttpGet("feed")]
    [AllowAnonymous]
    public async Task<ActionResult<IReadOnlyList<PostFeedItemDto>>> GetFeed(
        [FromQuery] int take = 25,
        [FromQuery] string? vibeTag = null,
        [FromQuery] string? type = null,
        CancellationToken cancellationToken = default
    )
    {
        var userId = User.Identity?.IsAuthenticated == true ? User.GetRequiredUserId() : null;
        return Ok(await postsService.GetFeedAsync(userId, take, vibeTag, type, cancellationToken));
    }

    [HttpGet("shorts")]
    [AllowAnonymous]
    public async Task<ActionResult<IReadOnlyList<PostFeedItemDto>>> GetShorts(
        [FromQuery] int take = 24,
        [FromQuery] string scope = "global",
        [FromQuery] double? latitude = null,
        [FromQuery] double? longitude = null,
        [FromQuery] double? radiusKm = null,
        CancellationToken cancellationToken = default
    )
    {
        var userId = User.Identity?.IsAuthenticated == true ? User.GetRequiredUserId() : null;
        return Ok(
            await postsService.GetShortsFeedAsync(
                userId,
                take,
                scope,
                latitude,
                longitude,
                radiusKm,
                cancellationToken
            )
        );
    }

    [HttpGet("user/{userId}")]
    [AllowAnonymous]
    public async Task<ActionResult<IReadOnlyList<PostFeedItemDto>>> GetUserPosts(
        string userId,
        [FromQuery] string? type,
        CancellationToken cancellationToken = default
    )
    {
        var currentUserId = User.Identity?.IsAuthenticated == true ? User.GetRequiredUserId() : null;
        return Ok(await postsService.GetUserPostsAsync(userId, currentUserId, type, cancellationToken));
    }

    [HttpGet("saved")]
    [Authorize]
    public async Task<ActionResult<IReadOnlyList<PostFeedItemDto>>> GetSaved(
        CancellationToken cancellationToken = default
    ) => Ok(await postsService.GetSavedPostsAsync(User.GetRequiredUserId(), cancellationToken));

    [HttpPost]
    [Authorize]
    public async Task<ActionResult<PostFeedItemDto>> Create(
        [FromBody] CreatePostRequest request,
        CancellationToken cancellationToken
    ) => Ok(await postsService.CreatePostAsync(User.GetRequiredUserId(), request, cancellationToken));

    [HttpPatch("{postId:guid}")]
    [Authorize]
    public async Task<ActionResult<PostFeedItemDto>> Update(
        Guid postId,
        [FromBody] UpdatePostRequest request,
        CancellationToken cancellationToken
    )
    {
        var updated = await postsService.UpdatePostAsync(
            postId,
            User.GetRequiredUserId(),
            request,
            cancellationToken
        );
        return updated is null ? NotFound() : Ok(updated);
    }

    [HttpPost("{postId:guid}/likes/toggle")]
    [Authorize]
    public async Task<ActionResult<PostInteractionDto>> ToggleLike(
        Guid postId,
        CancellationToken cancellationToken
    ) => Ok(await postsService.ToggleLikeAsync(postId, User.GetRequiredUserId(), cancellationToken));

    [HttpPost("{postId:guid}/comments")]
    [Authorize]
    public async Task<ActionResult<PostCommentDto>> AddComment(
        Guid postId,
        [FromBody] AddPostCommentRequest request,
        CancellationToken cancellationToken
    ) => Ok(await postsService.AddCommentAsync(postId, User.GetRequiredUserId(), request, cancellationToken));

    [HttpGet("{postId:guid}/comments")]
    [AllowAnonymous]
    public async Task<ActionResult<IReadOnlyList<PostCommentDto>>> GetComments(
        Guid postId,
        [FromQuery] int skip = 0,
        [FromQuery] int take = 50,
        CancellationToken cancellationToken = default
    )
    {
        var currentUserId = User.Identity?.IsAuthenticated == true ? User.GetRequiredUserId() : null;
        return Ok(await postsService.GetCommentsAsync(postId, currentUserId, skip, take, cancellationToken));
    }

    [HttpPatch("{postId:guid}/comments/{commentId:guid}")]
    [Authorize]
    public async Task<ActionResult<PostCommentDto>> UpdateComment(
        Guid postId,
        Guid commentId,
        [FromBody] UpdatePostCommentRequest request,
        CancellationToken cancellationToken
    )
    {
        var updated = await postsService.UpdateCommentAsync(
            postId,
            commentId,
            User.GetRequiredUserId(),
            request,
            cancellationToken
        );

        return updated is null ? NotFound() : Ok(updated);
    }

    [HttpDelete("{postId:guid}/comments/{commentId:guid}")]
    [Authorize]
    public async Task<IActionResult> DeleteComment(
        Guid postId,
        Guid commentId,
        CancellationToken cancellationToken
    )
    {
        var deleted = await postsService.DeleteCommentAsync(
            postId,
            commentId,
            User.GetRequiredUserId(),
            cancellationToken
        );
        return deleted ? Ok(new { deleted = true }) : NotFound();
    }

    [HttpPost("{postId:guid}/save")]
    [Authorize]
    public async Task<ActionResult<PostSaveDto>> ToggleSave(
        Guid postId,
        CancellationToken cancellationToken
    ) => Ok(await postsService.ToggleSaveAsync(postId, User.GetRequiredUserId(), cancellationToken));

    [HttpDelete("{postId:guid}")]
    [Authorize]
    public async Task<IActionResult> Delete(
        Guid postId,
        CancellationToken cancellationToken
    )
    {
        var deleted = await postsService.DeletePostAsync(postId, User.GetRequiredUserId(), cancellationToken);
        return deleted ? Ok(new { deleted = true }) : NotFound();
    }
}
