using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class PlacesController(IPlacesService placesService) : ControllerBase
{
    [HttpGet("nearby")]
    [AllowAnonymous]
    public async Task<ActionResult<IReadOnlyList<PlaceSummaryDto>>> Nearby(
        [FromQuery] NearbyPlacesRequest request,
        CancellationToken cancellationToken
    ) => Ok(await placesService.GetNearbyPlacesAsync(request, cancellationToken));

    [HttpGet("{placeId}")]
    [AllowAnonymous]
    public async Task<ActionResult<PlaceDetailDto?>> Detail(
        string placeId,
        [FromQuery] PlaceDetailRequest request,
        CancellationToken cancellationToken
    )
    {
        var detail = await placesService.GetPlaceDetailAsync(placeId, request, cancellationToken);
        return detail is null ? NotFound() : Ok(detail);
    }

    [HttpGet("forecast")]
    [AllowAnonymous]
    public async Task<ActionResult<IReadOnlyList<ForecastSlotDto>>> Forecast(
        [FromQuery] NearbyPlacesRequest request,
        CancellationToken cancellationToken
    ) => Ok(await placesService.GetForecastAsync(request, cancellationToken));

    [HttpPost("save")]
    [Authorize]
    public async Task<ActionResult<SavedPlaceStateDto>> ToggleSave(
        [FromBody] SavePlaceRequest request,
        CancellationToken cancellationToken
    ) => Ok(await placesService.ToggleSaveAsync(User.GetRequiredUserId(), request, cancellationToken));

    [HttpPost("community-signals")]
    [AllowAnonymous]
    public async Task<ActionResult<IReadOnlyList<PlaceCommunitySignalDto>>> CommunitySignals(
        [FromBody] PlaceCommunitySignalsRequest request,
        CancellationToken cancellationToken
    ) => Ok(await placesService.GetCommunitySignalsAsync(request, cancellationToken));
}
