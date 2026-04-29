namespace PulseCity.Application.Auth;

public sealed record AuthenticatedUser(
    string UserId,
    string Email,
    string DisplayName,
    string PhotoUrl,
    bool IsDevelopmentIdentity = false
);
