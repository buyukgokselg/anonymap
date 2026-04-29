using PulseCity.Application.DTOs;
using PulseCity.Domain.Entities;

namespace PulseCity.Infrastructure.Internal;

internal static class DtoMapper
{
    public static UserSummaryDto ToSummaryDto(this UserProfile user) =>
        new(
            user.Id,
            user.UserName,
            user.DisplayName,
            user.Bio,
            user.City,
            user.Gender,
            user.Mode,
            user.PrivacyLevel,
            user.IsVisible,
            user.IsOnline,
            user.ProfilePhotoUrl,
            user.Interests,
            user.FollowersCount,
            user.FollowingCount,
            user.FriendsCount,
            user.PulseScore,
            user.ActivityRatingAverage,
            user.ActivityRatingCount
        );

    public static PublicUserProfileDto ToPublicProfileDto(this UserProfile user) =>
        new(
            user.Id,
            user.UserName,
            user.DisplayName,
            user.Bio,
            user.City,
            user.Gender,
            user.Mode,
            user.MatchPreference,
            user.PrivacyLevel,
            user.IsVisible,
            user.IsOnline,
            user.ProfilePhotoUrl,
            user.Interests,
            user.LastSeenAt,
            user.CreatedAt,
            user.FollowersCount,
            user.FollowingCount,
            user.FriendsCount,
            user.PulseScore,
            user.PlacesVisited,
            user.VibeTagsCreated,
            user.PinnedPostId,
            user.PinnedAt
        );

    public static UserProfileDto ToProfileDto(this UserProfile user) =>
        new(
            user.Id,
            user.Email,
            user.UserName,
            user.DisplayName,
            user.Bio,
            user.City,
            user.Website,
            user.FirstName,
            user.LastName,
            user.Gender,
            user.BirthDate,
            user.Age,
            user.Purpose,
            user.MatchPreference,
            user.Mode,
            user.PrivacyLevel,
            user.PreferredLanguage,
            user.LocationGranularity,
            user.EnableDifferentialPrivacy,
            user.KAnonymityLevel,
            user.AllowAnalytics,
            user.IsVisible,
            user.IsOnline,
            user.ProfilePhotoUrl,
            user.PhotoUrls,
            user.Interests,
            user.Latitude,
            user.Longitude,
            user.LastSeenAt,
            user.CreatedAt,
            user.FollowersCount,
            user.FollowingCount,
            user.FriendsCount,
            user.PulseScore,
            user.PlacesVisited,
            user.VibeTagsCreated,
            user.PinnedPostId,
            user.PinnedAt,
            user.Orientation,
            user.RelationshipIntent,
            user.HeightCm,
            user.DrinkingStatus,
            user.SmokingStatus,
            user.IsPhotoVerified,
            string.IsNullOrWhiteSpace(user.VerificationStatus)
                ? (user.IsPhotoVerified ? "approved" : "none")
                : user.VerificationStatus,
            user.VerificationSubmittedAt,
            user.DatingPrompts,
            user.LookingForModes,
            user.Dealbreakers,
            user.EnabledFeatures
        );
}
