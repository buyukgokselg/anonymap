using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class PasswordResetAndStoryViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PasswordResetTokens",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    TokenHash = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UsedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    RequestedIp = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    UserAgent = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PasswordResetTokens", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PasswordResetTokens_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "StoryViews",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    StoryId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ViewerUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    ViewedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StoryViews", x => x.Id);
                    table.ForeignKey(
                        name: "FK_StoryViews_Highlights_StoryId",
                        column: x => x.StoryId,
                        principalTable: "Highlights",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_StoryViews_Users_ViewerUserId",
                        column: x => x.ViewerUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_PasswordResetTokens_ExpiresAt",
                table: "PasswordResetTokens",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_PasswordResetTokens_UserId_CreatedAt",
                table: "PasswordResetTokens",
                columns: new[] { "UserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_StoryViews_StoryId_ViewedAt",
                table: "StoryViews",
                columns: new[] { "StoryId", "ViewedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_StoryViews_StoryId_ViewerUserId",
                table: "StoryViews",
                columns: new[] { "StoryId", "ViewerUserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StoryViews_ViewerUserId",
                table: "StoryViews",
                column: "ViewerUserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PasswordResetTokens");

            migrationBuilder.DropTable(
                name: "StoryViews");
        }
    }
}
