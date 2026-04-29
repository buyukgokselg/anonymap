using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddActivityGroupChat : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ActivityId",
                table: "Chats",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Kind",
                table: "Chats",
                type: "nvarchar(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "direct");

            migrationBuilder.AddColumn<string>(
                name: "Title",
                table: "Chats",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_Chats_ActivityId",
                table: "Chats",
                column: "ActivityId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Chats_ActivityId",
                table: "Chats");

            migrationBuilder.DropColumn(
                name: "ActivityId",
                table: "Chats");

            migrationBuilder.DropColumn(
                name: "Kind",
                table: "Chats");

            migrationBuilder.DropColumn(
                name: "Title",
                table: "Chats");
        }
    }
}
