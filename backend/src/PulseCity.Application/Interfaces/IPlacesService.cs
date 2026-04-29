using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IPlacesService
{
    Task<IReadOnlyList<PlaceSummaryDto>> GetNearbyPlacesAsync(
        NearbyPlacesRequest request,
        CancellationToken cancellationToken = default
    );

    Task<PlaceDetailDto?> GetPlaceDetailAsync(
        string placeId,
        PlaceDetailRequest request,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<ForecastSlotDto>> GetForecastAsync(
        NearbyPlacesRequest request,
        CancellationToken cancellationToken = default
    );

    Task<SavedPlaceStateDto> ToggleSaveAsync(
        string userId,
        SavePlaceRequest request,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<PlaceCommunitySignalDto>> GetCommunitySignalsAsync(
        PlaceCommunitySignalsRequest request,
        CancellationToken cancellationToken = default
    );
}
