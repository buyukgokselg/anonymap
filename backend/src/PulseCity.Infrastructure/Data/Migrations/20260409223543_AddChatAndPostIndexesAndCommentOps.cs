using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddChatAndPostIndexesAndCommentOps : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Posts_UserId",
                table: "Posts");

            migrationBuilder.CreateIndex(
                name: "IX_Posts_Latitude_Longitude",
                table: "Posts",
                columns: new[] { "Latitude", "Longitude" });

            migrationBuilder.CreateIndex(
                name: "IX_Posts_UserId_CreatedAt",
                table: "Posts",
                columns: new[] { "UserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Chats_ExpiresAt",
                table: "Chats",
                column: "ExpiresAt");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Posts_Latitude_Longitude",
                table: "Posts");

            migrationBuilder.DropIndex(
                name: "IX_Posts_UserId_CreatedAt",
                table: "Posts");

            migrationBuilder.DropIndex(
                name: "IX_Chats_ExpiresAt",
                table: "Chats");

            migrationBuilder.CreateIndex(
                name: "IX_Posts_UserId",
                table: "Posts",
                column: "UserId");
        }
    }
}
