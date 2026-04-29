using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class PresenceController(IPresenceService presenceService) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> UpdatePresence(
        [FromBody] UpdatePresenceRequest request,
        CancellationToken cancellationToken
    )
    {
        await presenceService.UpdatePresenceAsync(User.GetRequiredUserId(), request, cancellationToken);
        return Ok(new { updated = true });
    }

    [HttpPost("online-status")]
    public async Task<IActionResult> UpdateOnlineStatus(
        [FromBody] UpdateOnlineStatusRequest request,
        CancellationToken cancellationToken
    )
    {
        await presenceService.UpdateOnlineStatusAsync(User.GetRequiredUserId(), request, cancellationToken);
        return Ok(new { updated = true });
    }

    [HttpGet("nearby")]
    public async Task<ActionResult<IReadOnlyList<NearbyUserDto>>> GetNearby(
        [FromQuery] NearbyUsersRequest request,
        CancellationToken cancellationToken
    ) => Ok(await presenceService.GetNearbyUsersAsync(User.GetRequiredUserId(), request, cancellationToken));
}
