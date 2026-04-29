using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.Auth;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class UsersController(IUsersService usersService) : ControllerBase
{
    [HttpGet("me")]
    public async Task<ActionResult<UserProfileDto>> GetMe(CancellationToken cancellationToken)
    {
        var currentUser = new AuthenticatedUser(
            User.GetRequiredUserId(),
            User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value ?? string.Empty,
            User.FindFirst(System.Security.Claims.ClaimTypes.Name)?.Value ?? string.Empty,
            User.FindFirst("picture")?.Value ?? string.Empty,
            bool.TryParse(User.FindFirst("is_dev_identity")?.Value, out var isDevIdentity) && isDevIdentity
        );

        return Ok(await usersService.GetOrCreateCurrentUserAsync(currentUser, cancellationToken));
    }

    [HttpPut("me")]
    public async Task<ActionResult<UserProfileDto>> UpdateMe(
        [FromBody] UpdateUserProfileRequest request,
        CancellationToken cancellationToken
    ) => Ok(await usersService.UpdateCurrentUserAsync(User.GetRequiredUserId(), request, cancellationToken));

    [HttpGet("{userId}")]
    public async Task<ActionResult<PublicUserProfileDto>> GetById(
        string userId,
        CancellationToken cancellationToken
    )
    {
        var user = await usersService.GetUserByIdAsync(
            userId,
            User.GetRequiredUserId(),
            cancellationToken
        );
        return user is null ? NotFound() : Ok(user);
    }

    [HttpGet("{userId}/followers")]
    public async Task<ActionResult<IReadOnlyList<UserSummaryDto>>> GetFollowers(
        string userId,
        CancellationToken cancellationToken
    ) => Ok(await usersService.GetFollowersAsync(
        userId,
        User.GetRequiredUserId(),
        cancellationToken
    ));

    [HttpGet("{userId}/following")]
    public async Task<ActionResult<IReadOnlyList<UserSummaryDto>>> GetFollowing(
        string userId,
        CancellationToken cancellationToken
    ) => Ok(await usersService.GetFollowingAsync(
        userId,
        User.GetRequiredUserId(),
        cancellationToken
    ));

    [HttpGet("{userId}/friends")]
    public async Task<ActionResult<IReadOnlyList<UserSummaryDto>>> GetFriends(
        string userId,
        CancellationToken cancellationToken
    ) => Ok(await usersService.GetFriendsAsync(
        userId,
        User.GetRequiredUserId(),
        cancellationToken
    ));

    [HttpGet("search")]
    public async Task<ActionResult<IReadOnlyList<UserSummaryDto>>> Search(
        [FromQuery] string q,
        [FromQuery] string? excludeUserId,
        CancellationToken cancellationToken
    ) => Ok(await usersService.SearchUsersAsync(q, excludeUserId ?? User.GetRequiredUserId(), cancellationToken));

    [HttpPost("me/export")]
    public async Task<ActionResult<UserDataExportDto>> ExportMyData(
        CancellationToken cancellationToken
    )
    {
        var publicBaseUrl = $"{Request.Scheme}://{Request.Host}";
        return Ok(
            await usersService.CreateDataExportAsync(
                User.GetRequiredUserId(),
                publicBaseUrl,
                cancellationToken
            )
        );
    }

    [HttpGet("me/export/{exportId:guid}/download")]
    public async Task<IActionResult> DownloadMyExport(
        Guid exportId,
        [FromQuery] string token,
        CancellationToken cancellationToken
    )
    {
        var export = await usersService.GetDataExportDownloadAsync(
            User.GetRequiredUserId(),
            exportId,
            token,
            cancellationToken
        );

        if (export is null)
        {
            return NotFound();
        }

        return File(export.Content, export.ContentType, export.FileName);
    }

    [HttpPut("me/pinned-moment")]
    public async Task<ActionResult<UserProfileDto>> UpdatePinnedMoment(
        [FromBody] UpdatePinnedMomentRequest request,
        CancellationToken cancellationToken
    ) => Ok(
        await usersService.UpdatePinnedMomentAsync(
            User.GetRequiredUserId(),
            request.PostId == Guid.Empty ? null : request.PostId,
            cancellationToken
        )
    );

    [HttpGet("{userId}/places")]
    public async Task<ActionResult<IReadOnlyList<UserPlaceVisitDto>>> GetPlacesVisited(
        string userId,
        CancellationToken cancellationToken
    ) => Ok(
        await usersService.GetPlacesVisitedAsync(
            userId,
            User.GetRequiredUserId(),
            cancellationToken
        )
    );

    [HttpGet("{userId}/signal-crossings")]
    public async Task<ActionResult<SignalCrossingSummaryDto>> GetSignalCrossings(
        string userId,
        CancellationToken cancellationToken
    ) => Ok(
        await usersService.GetSignalCrossingsAsync(
            userId,
            User.GetRequiredUserId(),
            cancellationToken
        )
    );

    [HttpPost("me/photo-verification")]
    public async Task<ActionResult<PhotoVerificationStatusDto>> SubmitPhotoVerification(
        [FromBody] SubmitPhotoVerificationRequest request,
        CancellationToken cancellationToken
    ) => Ok(
        await usersService.SubmitPhotoVerificationAsync(
            User.GetRequiredUserId(),
            request,
            cancellationToken
        )
    );

    [HttpGet("me/photo-verification")]
    public async Task<ActionResult<PhotoVerificationStatusDto>> GetPhotoVerificationStatus(
        CancellationToken cancellationToken
    ) => Ok(
        await usersService.GetPhotoVerificationStatusAsync(
            User.GetRequiredUserId(),
            cancellationToken
        )
    );
}
