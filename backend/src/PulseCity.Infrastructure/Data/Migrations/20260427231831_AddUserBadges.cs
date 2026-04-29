using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddUserBadges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "UserBadges",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    BadgeCode = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Tier = table.Column<int>(type: "int", nullable: false),
                    EarnedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    Progress = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserBadges", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserBadges_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserBadges_UserId",
                table: "UserBadges",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_UserBadges_UserId_BadgeCode",
                table: "UserBadges",
                columns: new[] { "UserId", "BadgeCode" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserBadges");
        }
    }
}
