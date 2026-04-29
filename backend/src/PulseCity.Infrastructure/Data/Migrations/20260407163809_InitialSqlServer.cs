using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialSqlServer : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "BlockedUsers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    BlockedUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BlockedUsers", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Follows",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FollowerUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    FollowingUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Follows", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "FriendRequests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FromUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    ToUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RespondedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FriendRequests", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Friendships",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserAId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    UserBId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Friendships", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PlaceSnapshots",
                columns: table => new
                {
                    PlaceId = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Vicinity = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    Latitude = table.Column<double>(type: "float", nullable: false),
                    Longitude = table.Column<double>(type: "float", nullable: false),
                    Rating = table.Column<double>(type: "float", nullable: false),
                    UserRatingsTotal = table.Column<int>(type: "int", nullable: false),
                    PriceLevel = table.Column<int>(type: "int", nullable: false),
                    IsOpenNow = table.Column<bool>(type: "bit", nullable: false),
                    GooglePulseScore = table.Column<int>(type: "int", nullable: false),
                    DensityScore = table.Column<int>(type: "int", nullable: false),
                    TrendScore = table.Column<int>(type: "int", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlaceSnapshots", x => x.PlaceId);
                });

            migrationBuilder.CreateTable(
                name: "PostComments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PostId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Text = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostComments", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PostLikes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PostId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostLikes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Posts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Text = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    LocationName = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    PlaceId = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Latitude = table.Column<double>(type: "float", nullable: true),
                    Longitude = table.Column<double>(type: "float", nullable: true),
                    PhotoUrls = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    VideoUrl = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    Rating = table.Column<double>(type: "float", nullable: false),
                    VibeTag = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CommentsCount = table.Column<int>(type: "int", nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Posts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Presences",
                columns: table => new
                {
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Latitude = table.Column<double>(type: "float", nullable: false),
                    Longitude = table.Column<double>(type: "float", nullable: false),
                    City = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Mode = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    ShareProfile = table.Column<bool>(type: "bit", nullable: false),
                    IsSignalActive = table.Column<bool>(type: "bit", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Presences", x => x.UserId);
                });

            migrationBuilder.CreateTable(
                name: "SavedPlaces",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    PlaceId = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    PlaceName = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Vicinity = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    Latitude = table.Column<double>(type: "float", nullable: true),
                    Longitude = table.Column<double>(type: "float", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SavedPlaces", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SavedPosts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    PostId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SavedPosts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "UserCredentials",
                columns: table => new
                {
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    PasswordHash = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    GoogleSubject = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    HasPassword = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserCredentials", x => x.UserId);
                });

            migrationBuilder.CreateTable(
                name: "UserReports",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ReporterUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    TargetUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Details = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserReports", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    UserName = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    NormalizedUserName = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    DisplayName = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    NormalizedDisplayName = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Bio = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    City = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    NormalizedCity = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Website = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Gender = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Age = table.Column<int>(type: "int", nullable: false),
                    Purpose = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Mode = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    PrivacyLevel = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    IsVisible = table.Column<bool>(type: "bit", nullable: false),
                    IsOnline = table.Column<bool>(type: "bit", nullable: false),
                    ProfilePhotoUrl = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    PhotoUrls = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Interests = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Latitude = table.Column<double>(type: "float", nullable: true),
                    Longitude = table.Column<double>(type: "float", nullable: true),
                    LastSeenAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    FollowersCount = table.Column<int>(type: "int", nullable: false),
                    FollowingCount = table.Column<int>(type: "int", nullable: false),
                    FriendsCount = table.Column<int>(type: "int", nullable: false),
                    PulseScore = table.Column<int>(type: "int", nullable: false),
                    PlacesVisited = table.Column<int>(type: "int", nullable: false),
                    VibeTagsCreated = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BlockedUsers_UserId_BlockedUserId",
                table: "BlockedUsers",
                columns: new[] { "UserId", "BlockedUserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Follows_FollowerUserId_FollowingUserId",
                table: "Follows",
                columns: new[] { "FollowerUserId", "FollowingUserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_FriendRequests_FromUserId_ToUserId_Status",
                table: "FriendRequests",
                columns: new[] { "FromUserId", "ToUserId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_FriendRequests_ToUserId_Status_CreatedAt",
                table: "FriendRequests",
                columns: new[] { "ToUserId", "Status", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Friendships_UserAId_UserBId",
                table: "Friendships",
                columns: new[] { "UserAId", "UserBId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PlaceSnapshots_UpdatedAt",
                table: "PlaceSnapshots",
                column: "UpdatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_PostComments_PostId_CreatedAt",
                table: "PostComments",
                columns: new[] { "PostId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_PostLikes_PostId_UserId",
                table: "PostLikes",
                columns: new[] { "PostId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Posts_CreatedAt",
                table: "Posts",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_Posts_PlaceId",
                table: "Posts",
                column: "PlaceId");

            migrationBuilder.CreateIndex(
                name: "IX_Presences_IsSignalActive_UpdatedAt",
                table: "Presences",
                columns: new[] { "IsSignalActive", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_SavedPlaces_UserId_PlaceId",
                table: "SavedPlaces",
                columns: new[] { "UserId", "PlaceId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SavedPosts_PostId_UserId",
                table: "SavedPosts",
                columns: new[] { "PostId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserCredentials_Email",
                table: "UserCredentials",
                column: "Email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserCredentials_GoogleSubject",
                table: "UserCredentials",
                column: "GoogleSubject",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_NormalizedCity",
                table: "Users",
                column: "NormalizedCity");

            migrationBuilder.CreateIndex(
                name: "IX_Users_NormalizedDisplayName",
                table: "Users",
                column: "NormalizedDisplayName");

            migrationBuilder.CreateIndex(
                name: "IX_Users_NormalizedUserName",
                table: "Users",
                column: "NormalizedUserName");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BlockedUsers");

            migrationBuilder.DropTable(
                name: "Follows");

            migrationBuilder.DropTable(
                name: "FriendRequests");

            migrationBuilder.DropTable(
                name: "Friendships");

            migrationBuilder.DropTable(
                name: "PlaceSnapshots");

            migrationBuilder.DropTable(
                name: "PostComments");

            migrationBuilder.DropTable(
                name: "PostLikes");

            migrationBuilder.DropTable(
                name: "Posts");

            migrationBuilder.DropTable(
                name: "Presences");

            migrationBuilder.DropTable(
                name: "SavedPlaces");

            migrationBuilder.DropTable(
                name: "SavedPosts");

            migrationBuilder.DropTable(
                name: "UserCredentials");

            migrationBuilder.DropTable(
                name: "UserReports");

            migrationBuilder.DropTable(
                name: "Users");
        }
    }
}
