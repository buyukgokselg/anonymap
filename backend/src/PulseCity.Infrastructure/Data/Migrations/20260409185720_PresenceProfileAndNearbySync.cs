using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class PresenceProfileAndNearbySync : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "BirthDate",
                table: "Users",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FirstName",
                table: "Users",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "LastName",
                table: "Users",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "MatchPreference",
                table: "Users",
                type: "nvarchar(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "auto");

            migrationBuilder.Sql(
                """
                UPDATE Users
                SET
                    FirstName = CASE
                        WHEN LTRIM(RTRIM(ISNULL(FirstName, N''))) <> N'' THEN LTRIM(RTRIM(FirstName))
                        WHEN CHARINDEX(N' ', LTRIM(RTRIM(ISNULL(DisplayName, N'')))) > 0 THEN LEFT(LTRIM(RTRIM(DisplayName)), CHARINDEX(N' ', LTRIM(RTRIM(DisplayName))) - 1)
                        WHEN LTRIM(RTRIM(ISNULL(DisplayName, N''))) <> N'' THEN LTRIM(RTRIM(DisplayName))
                        ELSE UserName
                    END,
                    LastName = CASE
                        WHEN LTRIM(RTRIM(ISNULL(LastName, N''))) <> N'' THEN LTRIM(RTRIM(LastName))
                        WHEN CHARINDEX(N' ', LTRIM(RTRIM(ISNULL(DisplayName, N'')))) > 0 THEN LTRIM(SUBSTRING(LTRIM(RTRIM(DisplayName)), CHARINDEX(N' ', LTRIM(RTRIM(DisplayName))) + 1, 200))
                        ELSE N''
                    END,
                    MatchPreference = CASE
                        WHEN LTRIM(RTRIM(ISNULL(MatchPreference, N''))) <> N'' AND LOWER(LTRIM(RTRIM(MatchPreference))) <> N'auto' THEN LOWER(LTRIM(RTRIM(MatchPreference)))
                        WHEN LOWER(LTRIM(RTRIM(ISNULL(Gender, N'')))) IN (N'male', N'man', N'erkek') THEN N'women'
                        WHEN LOWER(LTRIM(RTRIM(ISNULL(Gender, N'')))) IN (N'female', N'woman', N'kadin', N'kadın') THEN N'men'
                        ELSE N'everyone'
                    END;
                """
            );

            migrationBuilder.Sql(
                """
                CREATE OR ALTER VIEW dbo.vw_UserPresencePrivacyProjection
                AS
                SELECT
                    u.Id,
                    u.UserName,
                    u.DisplayName,
                    u.Bio,
                    COALESCE(NULLIF(p.City, N''), u.City, N'') AS City,
                    u.Gender,
                    COALESCE(NULLIF(p.Mode, N''), u.Mode, N'kesif') AS Mode,
                    u.MatchPreference,
                    u.PrivacyLevel,
                    u.LocationGranularity,
                    u.EnableDifferentialPrivacy,
                    u.KAnonymityLevel,
                    u.IsVisible,
                    u.IsOnline,
                    u.ProfilePhotoUrl,
                    u.Interests,
                    COALESCE(p.Latitude, u.Latitude) AS Latitude,
                    COALESCE(p.Longitude, u.Longitude) AS Longitude,
                    u.LastSeenAt,
                    u.FollowersCount,
                    u.FollowingCount,
                    u.FriendsCount,
                    u.PulseScore,
                    u.PlacesVisited,
                    u.VibeTagsCreated,
                    ISNULL(p.ShareProfile, CAST(1 AS bit)) AS ShareProfile,
                    ISNULL(p.IsSignalActive, CAST(0 AS bit)) AS IsSignalActive
                FROM Users AS u
                LEFT JOIN Presences AS p ON p.UserId = u.Id;
                """
            );

            migrationBuilder.Sql(
                """
                CREATE OR ALTER FUNCTION dbo.fn_GetNearbyVisibleUsers
                (
                    @CurrentUserId nvarchar(128),
                    @Latitude float,
                    @Longitude float,
                    @RadiusKm float
                )
                RETURNS TABLE
                AS
                RETURN
                SELECT
                    projection.Id,
                    projection.UserName,
                    projection.DisplayName,
                    projection.Bio,
                    projection.City,
                    projection.Gender,
                    projection.Mode,
                    projection.MatchPreference,
                    projection.PrivacyLevel,
                    projection.LocationGranularity,
                    projection.IsVisible,
                    projection.IsOnline,
                    projection.ProfilePhotoUrl,
                    projection.Interests,
                    projection.Latitude,
                    projection.Longitude,
                    projection.LastSeenAt,
                    projection.FollowersCount,
                    projection.FollowingCount,
                    projection.FriendsCount,
                    projection.PulseScore,
                    projection.PlacesVisited,
                    projection.VibeTagsCreated,
                    CAST(
                        geography::Point(@Latitude, @Longitude, 4326).STDistance(
                            geography::Point(projection.Latitude, projection.Longitude, 4326)
                        ) AS float
                    ) AS DistanceMeters,
                    projection.ShareProfile,
                    projection.IsSignalActive,
                    projection.EnableDifferentialPrivacy,
                    projection.KAnonymityLevel
                FROM dbo.vw_UserPresencePrivacyProjection AS projection
                WHERE
                    projection.Id <> @CurrentUserId
                    AND projection.IsVisible = 1
                    AND projection.IsOnline = 1
                    AND projection.Latitude IS NOT NULL
                    AND projection.Longitude IS NOT NULL
                    AND CAST(
                        geography::Point(@Latitude, @Longitude, 4326).STDistance(
                            geography::Point(projection.Latitude, projection.Longitude, 4326)
                        ) AS float
                    ) <= (@RadiusKm * 1000.0);
                """
            );
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                CREATE OR ALTER VIEW dbo.vw_UserPresencePrivacyProjection
                AS
                SELECT
                    u.Id,
                    u.UserName,
                    u.DisplayName,
                    u.Bio,
                    COALESCE(NULLIF(p.City, N''), u.City, N'') AS City,
                    COALESCE(NULLIF(p.Mode, N''), u.Mode, N'kesif') AS Mode,
                    u.PrivacyLevel,
                    u.LocationGranularity,
                    u.EnableDifferentialPrivacy,
                    u.KAnonymityLevel,
                    u.IsVisible,
                    u.IsOnline,
                    u.ProfilePhotoUrl,
                    u.Interests,
                    COALESCE(p.Latitude, u.Latitude) AS Latitude,
                    COALESCE(p.Longitude, u.Longitude) AS Longitude,
                    u.LastSeenAt,
                    u.FollowersCount,
                    u.FollowingCount,
                    u.FriendsCount,
                    u.PulseScore,
                    u.PlacesVisited,
                    u.VibeTagsCreated,
                    ISNULL(p.ShareProfile, CAST(1 AS bit)) AS ShareProfile,
                    ISNULL(p.IsSignalActive, CAST(0 AS bit)) AS IsSignalActive
                FROM Users AS u
                LEFT JOIN Presences AS p ON p.UserId = u.Id;
                """
            );

            migrationBuilder.Sql(
                """
                CREATE OR ALTER FUNCTION dbo.fn_GetNearbyVisibleUsers
                (
                    @CurrentUserId nvarchar(128),
                    @Latitude float,
                    @Longitude float,
                    @RadiusKm float
                )
                RETURNS TABLE
                AS
                RETURN
                SELECT
                    projection.Id,
                    projection.UserName,
                    projection.DisplayName,
                    projection.Bio,
                    projection.City,
                    projection.Mode,
                    projection.PrivacyLevel,
                    projection.LocationGranularity,
                    projection.IsVisible,
                    projection.IsOnline,
                    projection.ProfilePhotoUrl,
                    projection.Interests,
                    projection.Latitude,
                    projection.Longitude,
                    projection.LastSeenAt,
                    projection.FollowersCount,
                    projection.FollowingCount,
                    projection.FriendsCount,
                    projection.PulseScore,
                    projection.PlacesVisited,
                    projection.VibeTagsCreated,
                    CAST(
                        geography::Point(@Latitude, @Longitude, 4326).STDistance(
                            geography::Point(projection.Latitude, projection.Longitude, 4326)
                        ) AS float
                    ) AS DistanceMeters,
                    projection.ShareProfile,
                    projection.IsSignalActive,
                    projection.EnableDifferentialPrivacy,
                    projection.KAnonymityLevel
                FROM dbo.vw_UserPresencePrivacyProjection AS projection
                WHERE
                    projection.Id <> @CurrentUserId
                    AND projection.IsVisible = 1
                    AND projection.IsOnline = 1
                    AND projection.IsSignalActive = 1
                    AND projection.Latitude IS NOT NULL
                    AND projection.Longitude IS NOT NULL
                    AND CAST(
                        geography::Point(@Latitude, @Longitude, 4326).STDistance(
                            geography::Point(projection.Latitude, projection.Longitude, 4326)
                        ) AS float
                    ) <= (@RadiusKm * 1000.0);
                """
            );

            migrationBuilder.DropColumn(
                name: "BirthDate",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "FirstName",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "LastName",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "MatchPreference",
                table: "Users");
        }
    }
}
