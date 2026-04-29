using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddProfilePhase3Fields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "PinnedAt",
                table: "Users",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "PinnedPostId",
                table: "Users",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "SignalCrossings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserAId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    UserBId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    CrossedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    PlaceId = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    LocationLabel = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    ApproxLatitude = table.Column<double>(type: "float", nullable: true),
                    ApproxLongitude = table.Column<double>(type: "float", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SignalCrossings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SignalCrossings_Users_UserAId",
                        column: x => x.UserAId,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_SignalCrossings_Users_UserBId",
                        column: x => x.UserBId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_PinnedPostId",
                table: "Users",
                column: "PinnedPostId");

            migrationBuilder.CreateIndex(
                name: "IX_SignalCrossings_CrossedAt",
                table: "SignalCrossings",
                column: "CrossedAt");

            migrationBuilder.CreateIndex(
                name: "IX_SignalCrossings_UserAId_UserBId_CrossedAt",
                table: "SignalCrossings",
                columns: new[] { "UserAId", "UserBId", "CrossedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_SignalCrossings_UserBId",
                table: "SignalCrossings",
                column: "UserBId");

            migrationBuilder.AddForeignKey(
                name: "FK_Users_Posts_PinnedPostId",
                table: "Users",
                column: "PinnedPostId",
                principalTable: "Posts",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Users_Posts_PinnedPostId",
                table: "Users");

            migrationBuilder.DropTable(
                name: "SignalCrossings");

            migrationBuilder.DropIndex(
                name: "IX_Users_PinnedPostId",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "PinnedAt",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "PinnedPostId",
                table: "Users");
        }
    }
}
