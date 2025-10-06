using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CringeBank.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddUsers : Migration
    {
        private static readonly string[] UsersStatusLastSyncedIndexColumns = new[] { "Status", "LastSyncedAtUtc" };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.CreateTable(
                name: "Users",
                schema: "cringebank",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FirebaseUid = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    PhoneNumber = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: true),
                    DisplayName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    ProfileImageUrl = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    EmailVerified = table.Column<bool>(type: "bit", nullable: false),
                    ClaimsVersion = table.Column<int>(type: "int", nullable: false),
                    IsDisabled = table.Column<bool>(type: "bit", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    DisabledAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    DeletedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    LastLoginAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    LastSeenAppVersion = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    LastSyncedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CreatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Users_Email",
                schema: "cringebank",
                table: "Users",
                column: "Email",
                unique: true,
                filter: "[DeletedAtUtc] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Users_FirebaseUid",
                schema: "cringebank",
                table: "Users",
                column: "FirebaseUid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_Status_LastSyncedAtUtc",
                schema: "cringebank",
                table: "Users",
                columns: UsersStatusLastSyncedIndexColumns);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.DropTable(
                name: "Users",
                schema: "cringebank");
        }
    }
}
