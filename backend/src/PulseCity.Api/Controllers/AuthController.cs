using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using PulseCity.Api.Extensions;
using PulseCity.Application.Auth;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class AuthController(
    IAuthService authService,
    IUsersService usersService
) : ControllerBase
{
    [HttpPost("register")]
    [AllowAnonymous]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult<AuthResponseDto>> Register(
        [FromBody] RegisterRequest request,
        CancellationToken cancellationToken
    ) => Ok(await authService.RegisterAsync(request, cancellationToken));

    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult<AuthResponseDto>> Login(
        [FromBody] LoginRequest request,
        CancellationToken cancellationToken
    ) => Ok(await authService.LoginAsync(request, cancellationToken));

    [HttpPost("google")]
    [AllowAnonymous]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult<AuthResponseDto>> LoginWithGoogle(
        [FromBody] GoogleLoginRequest request,
        CancellationToken cancellationToken
    ) => Ok(await authService.LoginWithGoogleAsync(request, cancellationToken));

    [HttpPost("password/forgot")]
    [AllowAnonymous]
    [EnableRateLimiting("password-reset")]
    public async Task<ActionResult<PasswordResetRequestAcceptedDto>> ForgotPassword(
        [FromBody] ForgotPasswordRequest request,
        CancellationToken cancellationToken
    ) => Ok(await authService.RequestPasswordResetAsync(
        request,
        HttpContext.Connection.RemoteIpAddress?.ToString(),
        Request.Headers.UserAgent.ToString(),
        cancellationToken
    ));

    [HttpPost("password/reset")]
    [AllowAnonymous]
    [EnableRateLimiting("password-reset")]
    public async Task<IActionResult> ResetPassword(
        [FromBody] ResetPasswordRequest request,
        CancellationToken cancellationToken
    )
    {
        await authService.ResetPasswordAsync(request, cancellationToken);
        return Ok(new PasswordResetRequestAcceptedDto(
            Sent: true,
            Message: "Password updated."
        ));
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<UserProfileDto>> Me(CancellationToken cancellationToken)
    {
        var currentUser = new AuthenticatedUser(
            User.GetRequiredUserId(),
            User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value ?? string.Empty,
            User.FindFirst(System.Security.Claims.ClaimTypes.Name)?.Value ?? string.Empty,
            User.FindFirst("picture")?.Value ?? string.Empty
        );

        return Ok(await usersService.GetOrCreateCurrentUserAsync(currentUser, cancellationToken));
    }

    [HttpDelete("me")]
    [Authorize]
    public async Task<IActionResult> DeleteAccount(CancellationToken cancellationToken)
    {
        await authService.DeleteAccountAsync(User.GetRequiredUserId(), cancellationToken);
        return Ok(new { deleted = true });
    }
}
