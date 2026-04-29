using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddChatArchiveSupport : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "ArchivedAt",
                table: "ChatParticipants",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsArchived",
                table: "ChatParticipants",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_ChatParticipants_UserId_IsArchived_JoinedAt",
                table: "ChatParticipants",
                columns: new[] { "UserId", "IsArchived", "JoinedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ChatParticipants_UserId_IsArchived_JoinedAt",
                table: "ChatParticipants");

            migrationBuilder.DropColumn(
                name: "ArchivedAt",
                table: "ChatParticipants");

            migrationBuilder.DropColumn(
                name: "IsArchived",
                table: "ChatParticipants");
        }
    }
}
