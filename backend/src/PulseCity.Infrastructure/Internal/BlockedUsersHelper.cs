using Microsoft.EntityFrameworkCore;
using PulseCity.Infrastructure.Data;

namespace PulseCity.Infrastructure.Internal;

internal static class BlockedUsersHelper
{
    internal static async Task<HashSet<string>> GetBlockedUserIdsAsync(
        PulseCityDbContext dbContext,
        string? userId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return new HashSet<string>(StringComparer.Ordinal);
        }

        var blocked = await dbContext.BlockedUsers.AsNoTracking()
            .Where(entry => entry.UserId == userId || entry.BlockedUserId == userId)
            .Select(entry => entry.UserId == userId ? entry.BlockedUserId : entry.UserId)
            .ToListAsync(cancellationToken);

        return blocked.ToHashSet(StringComparer.Ordinal);
    }
}
