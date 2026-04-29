using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class SocialController(ISocialService socialService) : ControllerBase
{
    [HttpGet("friend-requests")]
    public async Task<ActionResult<IReadOnlyList<FriendRequestDto>>> GetFriendRequests(
        CancellationToken cancellationToken
    ) => Ok(await socialService.GetIncomingFriendRequestsAsync(User.GetRequiredUserId(), cancellationToken));

    [HttpPost("friend-requests")]
    public async Task<ActionResult<FriendRequestDto?>> SendFriendRequest(
        [FromBody] SendFriendRequestRequest request,
        CancellationToken cancellationToken
    ) => Ok(await socialService.SendFriendRequestAsync(User.GetRequiredUserId(), request.TargetUserId, cancellationToken));

    [HttpGet("relationship/{targetUserId}")]
    public async Task<ActionResult<RelationshipStateDto>> GetRelationship(
        string targetUserId,
        CancellationToken cancellationToken
    ) => Ok(await socialService.GetRelationshipStateAsync(User.GetRequiredUserId(), targetUserId, cancellationToken));

    [HttpPost("friend-requests/{requestId:guid}/accept")]
    public async Task<IActionResult> AcceptFriendRequest(Guid requestId, CancellationToken cancellationToken)
    {
        var updated = await socialService.RespondToFriendRequestAsync(requestId, User.GetRequiredUserId(), true, cancellationToken);
        return updated ? Ok(new { accepted = true }) : NotFound();
    }

    [HttpPost("friend-requests/{requestId:guid}/decline")]
    public async Task<IActionResult> DeclineFriendRequest(Guid requestId, CancellationToken cancellationToken)
    {
        var updated = await socialService.RespondToFriendRequestAsync(requestId, User.GetRequiredUserId(), false, cancellationToken);
        return updated ? Ok(new { declined = true }) : NotFound();
    }

    [HttpDelete("friend-requests/{requestId:guid}")]
    public async Task<IActionResult> CancelFriendRequest(Guid requestId, CancellationToken cancellationToken)
    {
        var cancelled = await socialService.CancelOutgoingFriendRequestAsync(
            requestId,
            User.GetRequiredUserId(),
            cancellationToken
        );
        return cancelled ? Ok(new { cancelled = true }) : NotFound();
    }

    [HttpDelete("friends/{targetUserId}")]
    public async Task<IActionResult> RemoveFriend(
        string targetUserId,
        CancellationToken cancellationToken
    )
    {
        var removed = await socialService.RemoveFriendAsync(
            User.GetRequiredUserId(),
            targetUserId,
            cancellationToken
        );
        return removed ? Ok(new { removed = true }) : NotFound();
    }

    [HttpPost("follow/toggle")]
    public async Task<ActionResult<FollowStateDto>> ToggleFollow(
        [FromBody] ToggleFollowRequest request,
        CancellationToken cancellationToken
    ) => Ok(await socialService.ToggleFollowAsync(User.GetRequiredUserId(), request.TargetUserId, cancellationToken));

    [HttpPost("block")]
    public async Task<IActionResult> BlockUser(
        [FromBody] BlockUserRequest request,
        CancellationToken cancellationToken
    )
    {
        await socialService.BlockUserAsync(User.GetRequiredUserId(), request.TargetUserId, cancellationToken);
        return Ok(new { blocked = true });
    }

    [HttpPost("report")]
    public async Task<IActionResult> ReportUser(
        [FromBody] ReportUserRequest request,
        CancellationToken cancellationToken
    )
    {
        await socialService.ReportUserAsync(User.GetRequiredUserId(), request, cancellationToken);
        return Ok(new { reported = true });
    }

    [HttpPost("unblock")]
    public async Task<IActionResult> UnblockUser(
        [FromBody] BlockUserRequest request,
        CancellationToken cancellationToken
    )
    {
        var unblocked = await socialService.UnblockUserAsync(
            User.GetRequiredUserId(), request.TargetUserId, cancellationToken);
        return unblocked ? Ok(new { unblocked = true }) : NotFound();
    }

    [HttpGet("blocked")]
    public async Task<ActionResult<IReadOnlyList<BlockedUserDto>>> GetBlockedUsers(
        CancellationToken cancellationToken
    ) => Ok(await socialService.GetBlockedUsersAsync(User.GetRequiredUserId(), cancellationToken));
}
