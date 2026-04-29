using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddActivityRecurrence : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "RecurrenceParentId",
                table: "Activities",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RecurrenceRule",
                table: "Activities",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "RecurrenceUntil",
                table: "Activities",
                type: "datetimeoffset",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RecurrenceParentId",
                table: "Activities");

            migrationBuilder.DropColumn(
                name: "RecurrenceRule",
                table: "Activities");

            migrationBuilder.DropColumn(
                name: "RecurrenceUntil",
                table: "Activities");
        }
    }
}
