namespace PulseCity.Application.Interfaces;

public interface IPushNotificationService
{
    Task SendToUserAsync(string userId, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default);
    Task SendToUsersAsync(IEnumerable<string> userIds, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default);
    Task RegisterTokenAsync(string userId, string token, string platform, CancellationToken cancellationToken = default);
    Task UnregisterTokenAsync(string userId, string token, CancellationToken cancellationToken = default);
}
