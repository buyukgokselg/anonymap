using System;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    [DbContext(typeof(PulseCityDbContext))]
    [Migration("20260411120000_ChatMessageVisibilityHardening")]
    /// <inheritdoc />
    public partial class ChatMessageVisibilityHardening : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "DeletedAt",
                table: "ChatParticipants",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "DeletedAt",
                table: "ChatMessages",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeletedByUserId",
                table: "ChatMessages",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "UpdatedAt",
                table: "ChatMessages",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ChatMessageHiddenStates",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MessageId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    HiddenAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChatMessageHiddenStates", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ChatMessageHiddenStates_ChatMessages_MessageId",
                        column: x => x.MessageId,
                        principalTable: "ChatMessages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ChatMessageHiddenStates_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessageHiddenStates_MessageId_UserId",
                table: "ChatMessageHiddenStates",
                columns: new[] { "MessageId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessageHiddenStates_UserId_HiddenAt",
                table: "ChatMessageHiddenStates",
                columns: new[] { "UserId", "HiddenAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_ChatId_DeletedAt",
                table: "ChatMessages",
                columns: new[] { "ChatId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ChatParticipants_UserId_DeletedAt",
                table: "ChatParticipants",
                columns: new[] { "UserId", "DeletedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ChatMessageHiddenStates");

            migrationBuilder.DropIndex(
                name: "IX_ChatMessages_ChatId_DeletedAt",
                table: "ChatMessages");

            migrationBuilder.DropIndex(
                name: "IX_ChatParticipants_UserId_DeletedAt",
                table: "ChatParticipants");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "ChatParticipants");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "DeletedByUserId",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "ChatMessages");
        }
    }
}
