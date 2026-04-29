namespace PulseCity.Application.DTOs;

public sealed record LobbyModeActivityDto(
    string Mode,
    int Count
);

public sealed record LobbySnapshotDto(
    int ActiveUsers,
    int LivePlaces,
    int RisingZones,
    IReadOnlyList<LobbyModeActivityDto> ModeActivity
);
