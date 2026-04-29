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
[EnableRateLimiting("discover")]
public sealed class DiscoverController(IUsersService usersService) : ControllerBase
{
    [HttpGet("people")]
    public async Task<ActionResult<DiscoverPeopleResponseDto>> GetPeople(
        [FromQuery] DiscoverPeopleQuery query,
        CancellationToken cancellationToken
    ) => Ok(
        await usersService.GetDiscoverPeopleAsync(
            User.GetRequiredUserId(),
            query,
            cancellationToken
        )
    );

    [HttpPost("pass")]
    public async Task<IActionResult> RecordPass(
        [FromBody] RecordDiscoverPassRequest request,
        CancellationToken cancellationToken
    )
    {
        await usersService.RecordDiscoverPassAsync(
            User.GetRequiredUserId(),
            request,
            cancellationToken
        );
        return NoContent();
    }

    [HttpDelete("pass/{targetUserId}")]
    public async Task<IActionResult> UndoPass(
        string targetUserId,
        CancellationToken cancellationToken
    )
    {
        var removed = await usersService.UndoDiscoverPassAsync(
            User.GetRequiredUserId(),
            targetUserId,
            cancellationToken
        );
        return removed ? NoContent() : NotFound();
    }
}
