using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddActivities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Activities",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HostUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Title = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    Category = table.Column<int>(type: "int", nullable: false),
                    Mode = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    CoverImageUrl = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    LocationName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    LocationAddress = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    Latitude = table.Column<double>(type: "float", nullable: false),
                    Longitude = table.Column<double>(type: "float", nullable: false),
                    City = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    NormalizedCity = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    StartsAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    EndsAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    ReminderMinutesBefore = table.Column<int>(type: "int", nullable: false),
                    ReminderSent = table.Column<bool>(type: "bit", nullable: false),
                    MaxParticipants = table.Column<int>(type: "int", nullable: true),
                    CurrentParticipantCount = table.Column<int>(type: "int", nullable: false),
                    Visibility = table.Column<int>(type: "int", nullable: false),
                    JoinPolicy = table.Column<int>(type: "int", nullable: false),
                    RequiresVerification = table.Column<bool>(type: "bit", nullable: false),
                    Interests = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    MinAge = table.Column<int>(type: "int", nullable: true),
                    MaxAge = table.Column<int>(type: "int", nullable: true),
                    PreferredGender = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CancellationReason = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    CancelledAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CompletedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Activities", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Activities_Users_HostUserId",
                        column: x => x.HostUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ActivityParticipations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActivityId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    JoinMessage = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    ResponseNote = table.Column<string>(type: "nvarchar(400)", maxLength: 400, nullable: true),
                    RequestedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RespondedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CancelledAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ActivityParticipations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ActivityParticipations_Activities_ActivityId",
                        column: x => x.ActivityId,
                        principalTable: "Activities",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ActivityParticipations_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_Activities_Category_Status_StartsAt",
                table: "Activities",
                columns: new[] { "Category", "Status", "StartsAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Activities_HostUserId_Status_StartsAt",
                table: "Activities",
                columns: new[] { "HostUserId", "Status", "StartsAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Activities_Latitude_Longitude",
                table: "Activities",
                columns: new[] { "Latitude", "Longitude" });

            migrationBuilder.CreateIndex(
                name: "IX_Activities_NormalizedCity_Status_StartsAt",
                table: "Activities",
                columns: new[] { "NormalizedCity", "Status", "StartsAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Activities_Status_StartsAt",
                table: "Activities",
                columns: new[] { "Status", "StartsAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ActivityParticipations_ActivityId_Status",
                table: "ActivityParticipations",
                columns: new[] { "ActivityId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_ActivityParticipations_ActivityId_UserId",
                table: "ActivityParticipations",
                columns: new[] { "ActivityId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ActivityParticipations_UserId_Status_RequestedAt",
                table: "ActivityParticipations",
                columns: new[] { "UserId", "Status", "RequestedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ActivityParticipations");

            migrationBuilder.DropTable(
                name: "Activities");
        }
    }
}
