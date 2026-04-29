namespace PulseCity.Application.Realtime;

public static class RealtimeGroups
{
    public static string User(string userId) => $"user:{userId}";
    public static string Chat(Guid chatId) => $"chat:{chatId}";
    public static string Presence(string city) => $"presence:{city.Trim().ToLowerInvariant()}";
}
