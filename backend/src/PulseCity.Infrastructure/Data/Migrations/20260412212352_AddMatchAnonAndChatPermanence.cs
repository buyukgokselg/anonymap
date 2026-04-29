using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PulseCity.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddMatchAnonAndChatPermanence : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "Initiator1AnonymousInChat",
                table: "Matches",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "PendingFriendRequestFromUserId",
                table: "Chats",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Initiator1AnonymousInChat",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "PendingFriendRequestFromUserId",
                table: "Chats");
        }
    }
}
