using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class StoryEntryKindsAndModelSync : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Highlights_UserId_CreatedAt",
                table: "Highlights");

            migrationBuilder.AddColumn<string>(
                name: "EntryKind",
                table: "Highlights",
                type: "nvarchar(24)",
                maxLength: 24,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "ExpiresAt",
                table: "Highlights",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Highlights_ExpiresAt",
                table: "Highlights",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_Highlights_UserId_EntryKind_CreatedAt",
                table: "Highlights",
                columns: new[] { "UserId", "EntryKind", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Highlights_ExpiresAt",
                table: "Highlights");

            migrationBuilder.DropIndex(
                name: "IX_Highlights_UserId_EntryKind_CreatedAt",
                table: "Highlights");

            migrationBuilder.DropColumn(
                name: "EntryKind",
                table: "Highlights");

            migrationBuilder.DropColumn(
                name: "ExpiresAt",
                table: "Highlights");

            migrationBuilder.CreateIndex(
                name: "IX_Highlights_UserId_CreatedAt",
                table: "Highlights",
                columns: new[] { "UserId", "CreatedAt" });
        }
    }
}
