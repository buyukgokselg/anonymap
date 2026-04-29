using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class BadgesController(IBadgesService badgesService) : ControllerBase
{
    /// <summary>Statik rozet kataloğu — UI ilk açılışta cacheler.</summary>
    [HttpGet("catalog")]
    [AllowAnonymous]
    public ActionResult<BadgeCatalogResponseDto> GetCatalog() =>
        Ok(badgesService.GetCatalog());

    /// <summary>Caller'ın rozet durumu (kazanılmış + kazanılmamış tüm rozetler).</summary>
    [HttpGet("me")]
    public async Task<ActionResult<UserBadgesResponseDto>> GetMine(
        CancellationToken cancellationToken
    )
    {
        var dto = await badgesService.GetForUserAsync(
            User.GetRequiredUserId(),
            cancellationToken
        );
        return Ok(dto);
    }

    /// <summary>Bir başka kullanıcının rozetleri (profil sayfası için).</summary>
    [HttpGet("users/{userId}")]
    public async Task<ActionResult<UserBadgesResponseDto>> GetForUser(
        string userId,
        CancellationToken cancellationToken
    )
    {
        var dto = await badgesService.GetForUserAsync(userId, cancellationToken);
        return Ok(dto);
    }
}
