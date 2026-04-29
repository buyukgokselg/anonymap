namespace PulseCity.Domain.Enums;

public enum NotificationType
{
    System = 0,

    // Friend
    FriendRequestReceived = 100,
    FriendRequestAccepted = 101,

    // Match / Chat
    MatchCreated = 200,
    MessageReceived = 201,

    // Activity
    ActivityJoinRequested = 300,
    ActivityJoinAccepted = 301,
    ActivityJoinDeclined = 302,
    ActivityCancelled = 303,
    ActivityReminder = 304,
    ActivityUpdated = 305,
    ActivityNewParticipant = 306,

    // Signal / Presence
    SignalNearby = 400,

    // Verification
    VerificationApproved = 500,
    VerificationRejected = 501,

    // Gamification
    BadgeEarned = 600,
}
