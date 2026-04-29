using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class MatchesController(IMatchesService matchesService) : ControllerBase
{
    [HttpGet("incoming/pending")]
    [EnableRateLimiting("match-read")]
    public async Task<ActionResult<IReadOnlyList<MatchDto>>> GetPendingIncoming(
        CancellationToken cancellationToken
    ) => Ok(await matchesService.GetPendingIncomingAsync(User.GetRequiredUserId(), cancellationToken));

    /// <summary>
    /// Inbox of users who have "liked" the caller and are awaiting a response.
    /// Returns a projected DTO with the liker's profile summary so the client
    /// doesn't need a second round-trip per row.
    /// </summary>
    [HttpGet("likes-me")]
    [EnableRateLimiting("match-read")]
    public async Task<ActionResult<LikesMeResponseDto>> GetLikesMe(
        [FromQuery] LikesMeQuery query,
        CancellationToken cancellationToken
    ) => Ok(await matchesService.GetLikesMeAsync(User.GetRequiredUserId(), query, cancellationToken));

    [HttpPost]
    [EnableRateLimiting("match-write")]
    public async Task<ActionResult<MatchDto>> Create(
        [FromBody] CreateMatchRequest request,
        CancellationToken cancellationToken
    ) => Ok(await matchesService.CreateAsync(User.GetRequiredUserId(), request, cancellationToken));

    [HttpGet]
    [EnableRateLimiting("match-read")]
    public async Task<ActionResult<IReadOnlyList<MatchDto>>> GetAll(
        CancellationToken cancellationToken
    ) => Ok(await matchesService.GetAllMatchesAsync(User.GetRequiredUserId(), cancellationToken));

    [HttpPost("{matchId:guid}/respond")]
    [EnableRateLimiting("match-write")]
    public async Task<IActionResult> Respond(
        Guid matchId,
        [FromBody] RespondToMatchRequest request,
        CancellationToken cancellationToken
    )
    {
        var updated = await matchesService.RespondAsync(matchId, User.GetRequiredUserId(), request, cancellationToken);
        return updated ? Ok(new { updated = true }) : NotFound();
    }
}
