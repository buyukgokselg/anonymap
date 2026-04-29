using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class RelationalExpansionForMessaging : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_UserCredentials_GoogleSubject",
                table: "UserCredentials");

            migrationBuilder.AlterColumn<string>(
                name: "GoogleSubject",
                table: "UserCredentials",
                type: "nvarchar(256)",
                maxLength: 256,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(256)",
                oldMaxLength: 256);

            migrationBuilder.CreateTable(
                name: "Chats",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedByUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    LastMessage = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    LastSenderId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    LastMessageTime = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    IsTemporary = table.Column<bool>(type: "bit", nullable: false),
                    IsFriendChat = table.Column<bool>(type: "bit", nullable: false),
                    DirectMessageKey = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Chats", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Chats_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Chats_Users_LastSenderId",
                        column: x => x.LastSenderId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Highlights",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Title = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    CoverUrl = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    Type = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Highlights", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Highlights_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ChatMessages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ChatId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SenderId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Text = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    PhotoUrl = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    VideoUrl = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    Latitude = table.Column<double>(type: "float", nullable: true),
                    Longitude = table.Column<double>(type: "float", nullable: true),
                    PhotoApproved = table.Column<bool>(type: "bit", nullable: true),
                    Reaction = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    DisappearSeconds = table.Column<int>(type: "int", nullable: true),
                    SharedPostId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    SharedPostAuthor = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    SharedPostLocation = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: true),
                    SharedPostVibe = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    SharedPostMediaUrl = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChatMessages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ChatMessages_Chats_ChatId",
                        column: x => x.ChatId,
                        principalTable: "Chats",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ChatMessages_Posts_SharedPostId",
                        column: x => x.SharedPostId,
                        principalTable: "Posts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_ChatMessages_Users_SenderId",
                        column: x => x.SenderId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ChatParticipants",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ChatId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    JoinedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    LastReadAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    UnreadCount = table.Column<int>(type: "int", nullable: false),
                    IsTyping = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChatParticipants", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ChatParticipants_Chats_ChatId",
                        column: x => x.ChatId,
                        principalTable: "Chats",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ChatParticipants_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Matches",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId1 = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    UserId2 = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Compatibility = table.Column<int>(type: "int", nullable: false),
                    CommonInterests = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RespondedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    ChatId = table.Column<Guid>(type: "uniqueidentifier", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Matches", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Matches_Chats_ChatId",
                        column: x => x.ChatId,
                        principalTable: "Chats",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_Matches_Users_UserId1",
                        column: x => x.UserId1,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_Matches_Users_UserId2",
                        column: x => x.UserId2,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserReports_ReporterUserId",
                table: "UserReports",
                column: "ReporterUserId");

            migrationBuilder.CreateIndex(
                name: "IX_UserReports_TargetUserId_CreatedAt",
                table: "UserReports",
                columns: new[] { "TargetUserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_UserCredentials_GoogleSubject",
                table: "UserCredentials",
                column: "GoogleSubject",
                unique: true,
                filter: "[GoogleSubject] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_SavedPosts_UserId",
                table: "SavedPosts",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Posts_UserId",
                table: "Posts",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_PostLikes_UserId",
                table: "PostLikes",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_PostComments_UserId",
                table: "PostComments",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Friendships_UserBId",
                table: "Friendships",
                column: "UserBId");

            migrationBuilder.CreateIndex(
                name: "IX_Follows_FollowingUserId",
                table: "Follows",
                column: "FollowingUserId");

            migrationBuilder.CreateIndex(
                name: "IX_BlockedUsers_BlockedUserId",
                table: "BlockedUsers",
                column: "BlockedUserId");

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_ChatId_CreatedAt",
                table: "ChatMessages",
                columns: new[] { "ChatId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_SenderId",
                table: "ChatMessages",
                column: "SenderId");

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_SharedPostId",
                table: "ChatMessages",
                column: "SharedPostId");

            migrationBuilder.CreateIndex(
                name: "IX_ChatParticipants_ChatId_UserId",
                table: "ChatParticipants",
                columns: new[] { "ChatId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ChatParticipants_UserId_JoinedAt",
                table: "ChatParticipants",
                columns: new[] { "UserId", "JoinedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Chats_CreatedByUserId",
                table: "Chats",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Chats_DirectMessageKey",
                table: "Chats",
                column: "DirectMessageKey",
                unique: true,
                filter: "[DirectMessageKey] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Chats_LastMessageTime",
                table: "Chats",
                column: "LastMessageTime");

            migrationBuilder.CreateIndex(
                name: "IX_Chats_LastSenderId",
                table: "Chats",
                column: "LastSenderId");

            migrationBuilder.CreateIndex(
                name: "IX_Highlights_UserId_CreatedAt",
                table: "Highlights",
                columns: new[] { "UserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Matches_ChatId",
                table: "Matches",
                column: "ChatId");

            migrationBuilder.CreateIndex(
                name: "IX_Matches_UserId1_UserId2_CreatedAt",
                table: "Matches",
                columns: new[] { "UserId1", "UserId2", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Matches_UserId2_Status_CreatedAt",
                table: "Matches",
                columns: new[] { "UserId2", "Status", "CreatedAt" });

            migrationBuilder.AddForeignKey(
                name: "FK_BlockedUsers_Users_BlockedUserId",
                table: "BlockedUsers",
                column: "BlockedUserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_BlockedUsers_Users_UserId",
                table: "BlockedUsers",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Follows_Users_FollowerUserId",
                table: "Follows",
                column: "FollowerUserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Follows_Users_FollowingUserId",
                table: "Follows",
                column: "FollowingUserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_FriendRequests_Users_FromUserId",
                table: "FriendRequests",
                column: "FromUserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_FriendRequests_Users_ToUserId",
                table: "FriendRequests",
                column: "ToUserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Friendships_Users_UserAId",
                table: "Friendships",
                column: "UserAId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Friendships_Users_UserBId",
                table: "Friendships",
                column: "UserBId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_PostComments_Posts_PostId",
                table: "PostComments",
                column: "PostId",
                principalTable: "Posts",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PostComments_Users_UserId",
                table: "PostComments",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_PostLikes_Posts_PostId",
                table: "PostLikes",
                column: "PostId",
                principalTable: "Posts",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PostLikes_Users_UserId",
                table: "PostLikes",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Posts_Users_UserId",
                table: "Posts",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Presences_Users_UserId",
                table: "Presences",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_SavedPlaces_Users_UserId",
                table: "SavedPlaces",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_SavedPosts_Posts_PostId",
                table: "SavedPosts",
                column: "PostId",
                principalTable: "Posts",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_SavedPosts_Users_UserId",
                table: "SavedPosts",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_UserCredentials_Users_UserId",
                table: "UserCredentials",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserReports_Users_ReporterUserId",
                table: "UserReports",
                column: "ReporterUserId",
                principalTable: "Users",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_UserReports_Users_TargetUserId",
                table: "UserReports",
                column: "TargetUserId",
                principalTable: "Users",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_BlockedUsers_Users_BlockedUserId",
                table: "BlockedUsers");

            migrationBuilder.DropForeignKey(
                name: "FK_BlockedUsers_Users_UserId",
                table: "BlockedUsers");

            migrationBuilder.DropForeignKey(
                name: "FK_Follows_Users_FollowerUserId",
                table: "Follows");

            migrationBuilder.DropForeignKey(
                name: "FK_Follows_Users_FollowingUserId",
                table: "Follows");

            migrationBuilder.DropForeignKey(
                name: "FK_FriendRequests_Users_FromUserId",
                table: "FriendRequests");

            migrationBuilder.DropForeignKey(
                name: "FK_FriendRequests_Users_ToUserId",
                table: "FriendRequests");

            migrationBuilder.DropForeignKey(
                name: "FK_Friendships_Users_UserAId",
                table: "Friendships");

            migrationBuilder.DropForeignKey(
                name: "FK_Friendships_Users_UserBId",
                table: "Friendships");

            migrationBuilder.DropForeignKey(
                name: "FK_PostComments_Posts_PostId",
                table: "PostComments");

            migrationBuilder.DropForeignKey(
                name: "FK_PostComments_Users_UserId",
                table: "PostComments");

            migrationBuilder.DropForeignKey(
                name: "FK_PostLikes_Posts_PostId",
                table: "PostLikes");

            migrationBuilder.DropForeignKey(
                name: "FK_PostLikes_Users_UserId",
                table: "PostLikes");

            migrationBuilder.DropForeignKey(
                name: "FK_Posts_Users_UserId",
                table: "Posts");

            migrationBuilder.DropForeignKey(
                name: "FK_Presences_Users_UserId",
                table: "Presences");

            migrationBuilder.DropForeignKey(
                name: "FK_SavedPlaces_Users_UserId",
                table: "SavedPlaces");

            migrationBuilder.DropForeignKey(
                name: "FK_SavedPosts_Posts_PostId",
                table: "SavedPosts");

            migrationBuilder.DropForeignKey(
                name: "FK_SavedPosts_Users_UserId",
                table: "SavedPosts");

            migrationBuilder.DropForeignKey(
                name: "FK_UserCredentials_Users_UserId",
                table: "UserCredentials");

            migrationBuilder.DropForeignKey(
                name: "FK_UserReports_Users_ReporterUserId",
                table: "UserReports");

            migrationBuilder.DropForeignKey(
                name: "FK_UserReports_Users_TargetUserId",
                table: "UserReports");

            migrationBuilder.DropTable(
                name: "ChatMessages");

            migrationBuilder.DropTable(
                name: "ChatParticipants");

            migrationBuilder.DropTable(
                name: "Highlights");

            migrationBuilder.DropTable(
                name: "Matches");

            migrationBuilder.DropTable(
                name: "Chats");

            migrationBuilder.DropIndex(
                name: "IX_UserReports_ReporterUserId",
                table: "UserReports");

            migrationBuilder.DropIndex(
                name: "IX_UserReports_TargetUserId_CreatedAt",
                table: "UserReports");

            migrationBuilder.DropIndex(
                name: "IX_UserCredentials_GoogleSubject",
                table: "UserCredentials");

            migrationBuilder.DropIndex(
                name: "IX_SavedPosts_UserId",
                table: "SavedPosts");

            migrationBuilder.DropIndex(
                name: "IX_Posts_UserId",
                table: "Posts");

            migrationBuilder.DropIndex(
                name: "IX_PostLikes_UserId",
                table: "PostLikes");

            migrationBuilder.DropIndex(
                name: "IX_PostComments_UserId",
                table: "PostComments");

            migrationBuilder.DropIndex(
                name: "IX_Friendships_UserBId",
                table: "Friendships");

            migrationBuilder.DropIndex(
                name: "IX_Follows_FollowingUserId",
                table: "Follows");

            migrationBuilder.DropIndex(
                name: "IX_BlockedUsers_BlockedUserId",
                table: "BlockedUsers");

            migrationBuilder.AlterColumn<string>(
                name: "GoogleSubject",
                table: "UserCredentials",
                type: "nvarchar(256)",
                maxLength: 256,
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "nvarchar(256)",
                oldMaxLength: 256,
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserCredentials_GoogleSubject",
                table: "UserCredentials",
                column: "GoogleSubject",
                unique: true);
        }
    }
}
