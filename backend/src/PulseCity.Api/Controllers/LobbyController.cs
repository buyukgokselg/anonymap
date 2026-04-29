using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[AllowAnonymous]
public sealed class LobbyController(IPresenceService presenceService) : ControllerBase
{
    [HttpGet("snapshot")]
    public async Task<ActionResult<LobbySnapshotDto>> GetSnapshot(
        CancellationToken cancellationToken
    ) => Ok(await presenceService.GetLobbySnapshotAsync(cancellationToken));
}
