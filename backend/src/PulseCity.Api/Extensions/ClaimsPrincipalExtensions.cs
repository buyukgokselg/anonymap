using System.Security.Claims;

namespace PulseCity.Api.Extensions;

internal static class ClaimsPrincipalExtensions
{
    public static string GetRequiredUserId(this ClaimsPrincipal principal) =>
        principal.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? throw new InvalidOperationException("Authenticated user id is missing.");
}
