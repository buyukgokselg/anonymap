using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class ActivitiesController(IActivitiesService activitiesService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<ActivityListResponseDto>> Search(
        [FromQuery] ActivityListQuery query,
        CancellationToken cancellationToken
    )
    {
        var dto = await activitiesService.SearchAsync(User.GetRequiredUserId(), query, cancellationToken);
        return Ok(dto);
    }

    [HttpGet("hosting")]
    public async Task<ActionResult<ActivityListResponseDto>> ListHosting(
        CancellationToken cancellationToken
    ) => Ok(await activitiesService.ListHostingAsync(User.GetRequiredUserId(), cancellationToken));

    [HttpGet("joined")]
    public async Task<ActionResult<ActivityListResponseDto>> ListJoined(
        CancellationToken cancellationToken
    ) => Ok(await activitiesService.ListJoinedAsync(User.GetRequiredUserId(), cancellationToken));

    [HttpGet("{activityId:guid}")]
    public async Task<ActionResult<ActivityDto>> Get(
        Guid activityId,
        CancellationToken cancellationToken
    )
    {
        var dto = await activitiesService.GetAsync(activityId, User.GetRequiredUserId(), cancellationToken);
        return dto is null ? NotFound() : Ok(dto);
    }

    [HttpGet("{activityId:guid}/participants")]
    public async Task<ActionResult<ActivityParticipationListDto>> ListParticipants(
        Guid activityId,
        CancellationToken cancellationToken
    ) => Ok(await activitiesService.ListParticipantsAsync(activityId, User.GetRequiredUserId(), cancellationToken));

    [HttpPost]
    public async Task<ActionResult<ActivityDto>> Create(
        [FromBody] CreateActivityRequest request,
        CancellationToken cancellationToken
    )
    {
        var dto = await activitiesService.CreateAsync(User.GetRequiredUserId(), request, cancellationToken);
        return CreatedAtAction(nameof(Get), new { activityId = dto.Id }, dto);
    }

    [HttpPatch("{activityId:guid}")]
    public async Task<ActionResult<ActivityDto>> Update(
        Guid activityId,
        [FromBody] UpdateActivityRequest request,
        CancellationToken cancellationToken
    )
    {
        var dto = await activitiesService.UpdateAsync(activityId, User.GetRequiredUserId(), request, cancellationToken);
        return dto is null ? NotFound() : Ok(dto);
    }

    [HttpPost("{activityId:guid}/cancel")]
    public async Task<IActionResult> Cancel(
        Guid activityId,
        [FromBody] CancelActivityRequest request,
        CancellationToken cancellationToken
    )
    {
        var ok = await activitiesService.CancelAsync(activityId, User.GetRequiredUserId(), request, cancellationToken);
        return ok ? NoContent() : NotFound();
    }

    [HttpPost("{activityId:guid}/join")]
    public async Task<ActionResult<ActivityParticipationDto>> Join(
        Guid activityId,
        [FromBody] JoinActivityRequest request,
        CancellationToken cancellationToken
    )
    {
        var dto = await activitiesService.JoinAsync(activityId, User.GetRequiredUserId(), request, cancellationToken);
        return dto is null ? NotFound() : Ok(dto);
    }

    [HttpPost("{activityId:guid}/leave")]
    public async Task<IActionResult> Leave(
        Guid activityId,
        CancellationToken cancellationToken
    )
    {
        var ok = await activitiesService.LeaveAsync(activityId, User.GetRequiredUserId(), cancellationToken);
        return ok ? NoContent() : NotFound();
    }

    [HttpPost("{activityId:guid}/participants/{participationId:guid}/respond")]
    public async Task<ActionResult<ActivityParticipationDto>> RespondJoin(
        Guid activityId,
        Guid participationId,
        [FromBody] RespondJoinRequest request,
        CancellationToken cancellationToken
    )
    {
        var dto = await activitiesService.RespondJoinAsync(
            activityId,
            participationId,
            User.GetRequiredUserId(),
            request,
            cancellationToken);
        return dto is null ? NotFound() : Ok(dto);
    }

    [HttpGet("{activityId:guid}/chat")]
    public async Task<ActionResult<ChatThreadDto>> GetGroupChat(
        Guid activityId,
        CancellationToken cancellationToken
    )
    {
        var dto = await activitiesService.GetOrCreateGroupChatAsync(
            activityId,
            User.GetRequiredUserId(),
            cancellationToken);
        return dto is null ? NotFound() : Ok(dto);
    }

    [HttpGet("{activityId:guid}/ratings")]
    public async Task<ActionResult<ActivityRatingListDto>> ListRatings(
        Guid activityId,
        CancellationToken cancellationToken
    ) => Ok(await activitiesService.ListActivityRatingsAsync(
        activityId, User.GetRequiredUserId(), cancellationToken));

    [HttpPost("{activityId:guid}/ratings")]
    public async Task<ActionResult<ActivityRatingDto>> CreateRating(
        Guid activityId,
        [FromBody] CreateActivityRatingRequest request,
        CancellationToken cancellationToken
    )
    {
        var dto = await activitiesService.CreateRatingAsync(
            activityId, User.GetRequiredUserId(), request, cancellationToken);
        return dto is null ? NotFound() : Ok(dto);
    }

    [HttpGet("ratings/pending")]
    public async Task<ActionResult<PendingRatingListDto>> ListPendingRatings(
        CancellationToken cancellationToken
    ) => Ok(await activitiesService.ListPendingRatingsAsync(
        User.GetRequiredUserId(), cancellationToken));

    [HttpGet("users/{userId}/ratings")]
    public async Task<ActionResult<ActivityRatingListDto>> ListUserRatings(
        string userId,
        CancellationToken cancellationToken
    ) => Ok(await activitiesService.ListUserRatingsAsync(userId, cancellationToken));
}
