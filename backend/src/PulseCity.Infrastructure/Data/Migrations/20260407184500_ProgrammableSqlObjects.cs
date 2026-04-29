using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Infrastructure;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    [DbContext(typeof(PulseCityDbContext))]
    [Migration("20260407184500_ProgrammableSqlObjects")]
    public partial class ProgrammableSqlObjects : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                CREATE OR ALTER VIEW dbo.vw_PostFeedSummary
                AS
                SELECT
                    p.Id,
                    p.UserId,
                    u.DisplayName AS UserDisplayName,
                    u.ProfilePhotoUrl AS UserProfilePhotoUrl,
                    p.Text,
                    p.LocationName AS Location,
                    p.PlaceId,
                    p.Latitude,
                    p.Longitude,
                    p.PhotoUrls,
                    p.VideoUrl,
                    p.Rating,
                    p.VibeTag,
                    CASE WHEN p.Type = 1 THEN N'short' ELSE N'post' END AS Type,
                    ISNULL(lk.LikesCount, 0) AS LikesCount,
                    p.CommentsCount,
                    p.CreatedAt
                FROM Posts AS p
                INNER JOIN Users AS u ON u.Id = p.UserId
                LEFT JOIN
                (
                    SELECT PostId, COUNT(*) AS LikesCount
                    FROM PostLikes
                    GROUP BY PostId
                ) AS lk ON lk.PostId = p.Id;
                """
            );

            migrationBuilder.Sql(
                """
                CREATE OR ALTER PROCEDURE dbo.usp_GetSavedPostsByUser
                    @UserId nvarchar(128)
                AS
                BEGIN
                    SET NOCOUNT ON;

                    SELECT v.*
                    FROM SavedPosts AS sp
                    INNER JOIN dbo.vw_PostFeedSummary AS v ON v.Id = sp.PostId
                    WHERE sp.UserId = @UserId
                    ORDER BY sp.CreatedAt DESC;
                END
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
                WITH CandidateUsers AS
                (
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
                    LEFT JOIN Presences AS p ON p.UserId = u.Id
                    WHERE
                        u.Id <> @CurrentUserId
                        AND u.IsVisible = 1
                        AND u.IsOnline = 1
                        AND ISNULL(p.IsSignalActive, 0) = 1
                        AND COALESCE(p.Latitude, u.Latitude) IS NOT NULL
                        AND COALESCE(p.Longitude, u.Longitude) IS NOT NULL
                )
                SELECT
                    cu.Id,
                    cu.Email,
                    cu.UserName,
                    cu.DisplayName,
                    cu.Bio,
                    cu.City,
                    cu.Website,
                    cu.Gender,
                    cu.Age,
                    cu.Purpose,
                    cu.Mode,
                    cu.PrivacyLevel,
                    cu.IsVisible,
                    cu.IsOnline,
                    cu.ProfilePhotoUrl,
                    cu.PhotoUrls,
                    cu.Interests,
                    cu.Latitude,
                    cu.Longitude,
                    cu.LastSeenAt,
                    cu.FollowersCount,
                    cu.FollowingCount,
                    cu.FriendsCount,
                    cu.PulseScore,
                    cu.PlacesVisited,
                    cu.VibeTagsCreated,
                    CAST(
                        geography::Point(@Latitude, @Longitude, 4326).STDistance(
                            geography::Point(cu.Latitude, cu.Longitude, 4326)
                        ) AS float
                    ) AS DistanceMeters,
                    cu.ShareProfile,
                    cu.IsSignalActive
                FROM CandidateUsers AS cu
                WHERE
                    CAST(
                        geography::Point(@Latitude, @Longitude, 4326).STDistance(
                            geography::Point(cu.Latitude, cu.Longitude, 4326)
                        ) AS float
                    ) <= (@RadiusKm * 1000.0);
                """
            );
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP FUNCTION IF EXISTS dbo.fn_GetNearbyVisibleUsers;");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_UpsertUserPresence;");
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_GetSavedPostsByUser;");
            migrationBuilder.Sql("DROP VIEW IF EXISTS dbo.vw_PostFeedSummary;");
        }
    }
}
