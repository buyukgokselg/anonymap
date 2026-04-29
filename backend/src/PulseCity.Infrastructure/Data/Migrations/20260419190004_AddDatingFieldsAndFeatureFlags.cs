using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddDatingFieldsAndFeatureFlags : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DatingPrompts",
                table: "Users",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Dealbreakers",
                table: "Users",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "DrinkingStatus",
                table: "Users",
                type: "nvarchar(24)",
                maxLength: 24,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "EnabledFeatures",
                table: "Users",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "HeightCm",
                table: "Users",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsPhotoVerified",
                table: "Users",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "LookingForModes",
                table: "Users",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Orientation",
                table: "Users",
                type: "nvarchar(24)",
                maxLength: 24,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "RelationshipIntent",
                table: "Users",
                type: "nvarchar(24)",
                maxLength: 24,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "SmokingStatus",
                table: "Users",
                type: "nvarchar(24)",
                maxLength: 24,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_Users_Mode",
                table: "Users",
                column: "Mode");

            migrationBuilder.CreateIndex(
                name: "IX_Users_RelationshipIntent",
                table: "Users",
                column: "RelationshipIntent");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Users_Mode",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Users_RelationshipIntent",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "DatingPrompts",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "Dealbreakers",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "DrinkingStatus",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "EnabledFeatures",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "HeightCm",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "IsPhotoVerified",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "LookingForModes",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "Orientation",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "RelationshipIntent",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "SmokingStatus",
                table: "Users");
        }
    }
}
