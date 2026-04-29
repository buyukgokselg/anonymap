using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class PrivacyRealtimeLocalization : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "AllowAnalytics",
                table: "Users",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<bool>(
                name: "EnableDifferentialPrivacy",
                table: "Users",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<int>(
                name: "KAnonymityLevel",
                table: "Users",
                type: "int",
                nullable: false,
                defaultValue: 3);

            migrationBuilder.AddColumn<string>(
                name: "LocationGranularity",
                table: "Users",
                type: "nvarchar(24)",
                maxLength: 24,
                nullable: false,
                defaultValue: "nearby");

            migrationBuilder.AddColumn<string>(
                name: "PreferredLanguage",
                table: "Users",
                type: "nvarchar(8)",
                maxLength: 8,
                nullable: false,
                defaultValue: "tr");

            migrationBuilder.CreateTable(
                name: "UserDataExports",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    FileName = table.Column<string>(type: "nvarchar(260)", maxLength: 260, nullable: false),
                    RelativePath = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    FileSizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserDataExports", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserDataExports_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserDataExports_ExpiresAt",
                table: "UserDataExports",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_UserDataExports_UserId_CreatedAt",
                table: "UserDataExports",
                columns: new[] { "UserId", "CreatedAt" });

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
                CREATE OR ALTER PROCEDURE dbo.usp_DeleteUserDataExport
                    @ExportId uniqueidentifier
                AS
                BEGIN
                    SET NOCOUNT ON;

                    DELETE FROM UserDataExports
                    WHERE Id = @ExportId;
                END
                """
            );
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP PROCEDURE IF EXISTS dbo.usp_DeleteUserDataExport;");
            migrationBuilder.Sql("DROP VIEW IF EXISTS dbo.vw_UserPresencePrivacyProjection;");
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

            migrationBuilder.DropTable(
                name: "UserDataExports");

            migrationBuilder.DropColumn(
                name: "AllowAnalytics",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "EnableDifferentialPrivacy",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "KAnonymityLevel",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "LocationGranularity",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "PreferredLanguage",
                table: "Users");
        }
    }
}
