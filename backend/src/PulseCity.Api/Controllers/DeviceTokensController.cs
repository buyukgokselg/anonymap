using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/device-tokens")]
[Authorize]
public sealed class DeviceTokensController(IPushNotificationService pushService) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Register(
        [FromBody] RegisterDeviceTokenRequest request,
        CancellationToken cancellationToken
    )
    {
        var userId = User.GetRequiredUserId();
        await pushService.RegisterTokenAsync(userId, request.Token, request.Platform ?? "android", cancellationToken);
        return Ok();
    }

    [HttpDelete]
    public async Task<IActionResult> Unregister(
        [FromBody] UnregisterDeviceTokenRequest request,
        CancellationToken cancellationToken
    )
    {
        var userId = User.GetRequiredUserId();
        await pushService.UnregisterTokenAsync(userId, request.Token, cancellationToken);
        return Ok();
    }
}

public sealed record RegisterDeviceTokenRequest(string Token, string? Platform);
public sealed record UnregisterDeviceTokenRequest(string Token);
