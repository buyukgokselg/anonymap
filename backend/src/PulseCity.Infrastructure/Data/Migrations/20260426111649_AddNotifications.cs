using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddNotifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Notifications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RecipientUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    ActorUserId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    Type = table.Column<int>(type: "int", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: false),
                    Body = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    DeepLink = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    RelatedEntityType = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    RelatedEntityId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    IsRead = table.Column<bool>(type: "bit", nullable: false),
                    ReadAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Notifications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Notifications_Users_RecipientUserId",
                        column: x => x.RecipientUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_RecipientUserId_CreatedAt",
                table: "Notifications",
                columns: new[] { "RecipientUserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_RecipientUserId_IsRead_CreatedAt",
                table: "Notifications",
                columns: new[] { "RecipientUserId", "IsRead", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Notifications");
        }
    }
}
