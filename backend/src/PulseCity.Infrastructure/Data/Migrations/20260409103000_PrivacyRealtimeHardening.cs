using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations;

public partial class PrivacyRealtimeHardening : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
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

        migrationBuilder.Sql(
            """
            CREATE OR ALTER PROCEDURE dbo.usp_UpsertUserPresence
                @UserId nvarchar(128),
                @Latitude float,
                @Longitude float,
                @City nvarchar(120),
                @Mode nvarchar(32),
                @ShareProfile bit,
                @IsSignalActive bit,
                @IsOnline bit
            AS
            BEGIN
                SET NOCOUNT ON;

                DECLARE @Now datetimeoffset = SYSUTCDATETIME();
                DECLARE @NormalizedCity nvarchar(120) = LOWER(LTRIM(RTRIM(ISNULL(@City, N''))));
                DECLARE @CleanMode nvarchar(32) = NULLIF(LTRIM(RTRIM(ISNULL(@Mode, N''))), N'');

                UPDATE Users
                SET
                    Latitude = @Latitude,
                    Longitude = @Longitude,
                    City = CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(@City, N''))), N'') IS NULL THEN City ELSE LTRIM(RTRIM(@City)) END,
                    NormalizedCity = CASE WHEN NULLIF(@NormalizedCity, N'') IS NULL THEN NormalizedCity ELSE @NormalizedCity END,
                    IsOnline = @IsOnline,
                    LastSeenAt = @Now,
                    UpdatedAt = @Now
                WHERE Id = @UserId;

                IF EXISTS (SELECT 1 FROM Presences WHERE UserId = @UserId)
                BEGIN
                    UPDATE Presences
                    SET
                        Latitude = @Latitude,
                        Longitude = @Longitude,
                        City = LTRIM(RTRIM(ISNULL(@City, N''))),
                        Mode = COALESCE(@CleanMode, Mode),
                        ShareProfile = @ShareProfile,
                        IsSignalActive = CASE WHEN @IsOnline = 1 THEN @IsSignalActive ELSE 0 END,
                        UpdatedAt = @Now
                    WHERE UserId = @UserId;
                END
                ELSE
                BEGIN
                    INSERT INTO Presences
                    (
                        UserId,
                        Latitude,
                        Longitude,
                        City,
                        Mode,
                        ShareProfile,
                        IsSignalActive,
                        UpdatedAt
                    )
                    VALUES
                    (
                        @UserId,
                        @Latitude,
                        @Longitude,
                        LTRIM(RTRIM(ISNULL(@City, N''))),
                        COALESCE(@CleanMode, N'kesif'),
                        @ShareProfile,
                        CASE WHEN @IsOnline = 1 THEN @IsSignalActive ELSE 0 END,
                        @Now
                    );
                END
            END
            """
        );
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(
            """
            CREATE OR ALTER VIEW dbo.vw_UserPresencePrivacyProjection
            AS
            SELECT
                u.Id,
                u.Email,
                u.UserName,
                u.DisplayName,
                u.Bio,
                COALESCE(NULLIF(p.City, N''), u.City, N'') AS City,
                u.Website,
                u.Gender,
                u.Age,
                u.Purpose,
                COALESCE(NULLIF(p.Mode, N''), u.Mode, N'kesif') AS Mode,
                u.PrivacyLevel,
                u.PreferredLanguage,
                u.LocationGranularity,
                u.EnableDifferentialPrivacy,
                u.KAnonymityLevel,
                u.AllowAnalytics,
                u.IsVisible,
                u.IsOnline,
                u.ProfilePhotoUrl,
                u.PhotoUrls,
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
                projection.Email,
                projection.UserName,
                projection.DisplayName,
                projection.Bio,
                projection.City,
                projection.Website,
                projection.Gender,
                projection.Age,
                projection.Purpose,
                projection.Mode,
                projection.PrivacyLevel,
                projection.PreferredLanguage,
                projection.LocationGranularity,
                projection.EnableDifferentialPrivacy,
                projection.KAnonymityLevel,
                projection.AllowAnalytics,
                projection.IsVisible,
                projection.IsOnline,
                projection.ProfilePhotoUrl,
                projection.PhotoUrls,
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
                projection.IsSignalActive
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

        migrationBuilder.Sql(
            """
            CREATE OR ALTER PROCEDURE dbo.usp_UpsertUserPresence
                @UserId nvarchar(128),
                @Latitude float,
                @Longitude float,
                @City nvarchar(120),
                @Mode nvarchar(32),
                @ShareProfile bit,
                @IsSignalActive bit,
                @IsOnline bit
            AS
            BEGIN
                SET NOCOUNT ON;

                DECLARE @Now datetimeoffset = SYSUTCDATETIME();
                DECLARE @NormalizedCity nvarchar(120) = LOWER(LTRIM(RTRIM(ISNULL(@City, N''))));
                DECLARE @CleanMode nvarchar(32) = NULLIF(LTRIM(RTRIM(ISNULL(@Mode, N''))), N'');

                UPDATE Users
                SET
                    Latitude = @Latitude,
                    Longitude = @Longitude,
                    City = CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(@City, N''))), N'') IS NULL THEN City ELSE LTRIM(RTRIM(@City)) END,
                    NormalizedCity = CASE WHEN NULLIF(@NormalizedCity, N'') IS NULL THEN NormalizedCity ELSE @NormalizedCity END,
                    Mode = COALESCE(@CleanMode, Mode),
                    IsOnline = @IsOnline,
                    LastSeenAt = @Now,
                    UpdatedAt = @Now
                WHERE Id = @UserId;

                IF EXISTS (SELECT 1 FROM Presences WHERE UserId = @UserId)
                BEGIN
                    UPDATE Presences
                    SET
                        Latitude = @Latitude,
                        Longitude = @Longitude,
                        City = LTRIM(RTRIM(ISNULL(@City, N''))),
                        Mode = COALESCE(@CleanMode, Mode),
                        ShareProfile = @ShareProfile,
                        IsSignalActive = CASE WHEN @IsOnline = 1 THEN @IsSignalActive ELSE 0 END,
                        UpdatedAt = @Now
                    WHERE UserId = @UserId;
                END
                ELSE
                BEGIN
                    INSERT INTO Presences
                    (
                        UserId,
                        Latitude,
                        Longitude,
                        City,
                        Mode,
                        ShareProfile,
                        IsSignalActive,
                        UpdatedAt
                    )
                    VALUES
                    (
                        @UserId,
                        @Latitude,
                        @Longitude,
                        LTRIM(RTRIM(ISNULL(@City, N''))),
                        COALESCE(@CleanMode, N'kesif'),
                        @ShareProfile,
                        CASE WHEN @IsOnline = 1 THEN @IsSignalActive ELSE 0 END,
                        @Now
                    );
                END
            END
            """
        );
    }
}
