using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddActivityRatings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "ActivityRatingAverage",
                table: "Users",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<int>(
                name: "ActivityRatingCount",
                table: "Users",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "ActivityRatings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActivityId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RaterUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    RatedUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Score = table.Column<int>(type: "int", nullable: false),
                    Comment = table.Column<string>(type: "nvarchar(800)", maxLength: 800, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ActivityRatings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ActivityRatings_Activities_ActivityId",
                        column: x => x.ActivityId,
                        principalTable: "Activities",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ActivityRatings_Users_RatedUserId",
                        column: x => x.RatedUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ActivityRatings_Users_RaterUserId",
                        column: x => x.RaterUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_ActivityRatings_ActivityId",
                table: "ActivityRatings",
                column: "ActivityId");

            migrationBuilder.CreateIndex(
                name: "IX_ActivityRatings_ActivityId_RaterUserId_RatedUserId",
                table: "ActivityRatings",
                columns: new[] { "ActivityId", "RaterUserId", "RatedUserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ActivityRatings_RatedUserId",
                table: "ActivityRatings",
                column: "RatedUserId");

            migrationBuilder.CreateIndex(
                name: "IX_ActivityRatings_RaterUserId",
                table: "ActivityRatings",
                column: "RaterUserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ActivityRatings");

            migrationBuilder.DropColumn(
                name: "ActivityRatingAverage",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "ActivityRatingCount",
                table: "Users");
        }
    }
}
