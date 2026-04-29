using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class StoryHighlightMetadata : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "LocationLabel",
                table: "Highlights",
                type: "nvarchar(160)",
                maxLength: 160,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MediaUrls",
                table: "Highlights",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "ModeTag",
                table: "Highlights",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PlaceId",
                table: "Highlights",
                type: "nvarchar(160)",
                maxLength: 160,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TextColorHex",
                table: "Highlights",
                type: "nvarchar(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<double>(
                name: "TextOffsetX",
                table: "Highlights",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "TextOffsetY",
                table: "Highlights",
                type: "float",
                nullable: false,
                defaultValue: 0.0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "LocationLabel",
                table: "Highlights");

            migrationBuilder.DropColumn(
                name: "MediaUrls",
                table: "Highlights");

            migrationBuilder.DropColumn(
                name: "ModeTag",
                table: "Highlights");

            migrationBuilder.DropColumn(
                name: "PlaceId",
                table: "Highlights");

            migrationBuilder.DropColumn(
                name: "TextColorHex",
                table: "Highlights");

            migrationBuilder.DropColumn(
                name: "TextOffsetX",
                table: "Highlights");

            migrationBuilder.DropColumn(
                name: "TextOffsetY",
                table: "Highlights");
        }
    }
}
