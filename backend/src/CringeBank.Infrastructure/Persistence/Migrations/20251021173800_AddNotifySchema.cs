using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1861 // Prefer static readonly for constant arrays in migrations

namespace CringeBank.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddNotifySchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.EnsureSchema(
                name: "notify");

            migrationBuilder.CreateTable(
                name: "Notifications",
                schema: "notify",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    public_id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "NEWSEQUENTIALID()"),
                    recipient_user_id = table.Column<long>(type: "bigint", nullable: false),
                    sender_user_id = table.Column<long>(type: "bigint", nullable: true),
                    type = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)10),
                    title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    body = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    action_url = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    image_url = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    payload_json = table.Column<string>(type: "nvarchar(max)", nullable: false, defaultValue: "{}"),
                    is_read = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    created_at_utc = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    read_at_utc = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Notifications", x => x.id);
                    table.ForeignKey(
                        name: "FK_Notifications_Users_recipient_user_id",
                        column: x => x.recipient_user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Notifications_Users_sender_user_id",
                        column: x => x.sender_user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "Outbox",
                schema: "notify",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    notification_id = table.Column<long>(type: "bigint", nullable: false),
                    channel = table.Column<byte>(type: "tinyint", nullable: false),
                    topic = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    payload_json = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    status = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)0),
                    retry_count = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    created_at_utc = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    processed_at_utc = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Outbox", x => x.id);
                    table.ForeignKey(
                        name: "FK_Outbox_Notifications_notification_id",
                        column: x => x.notification_id,
                        principalSchema: "notify",
                        principalTable: "Notifications",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_public_id",
                schema: "notify",
                table: "Notifications",
                column: "public_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_ReadState",
                schema: "notify",
                table: "Notifications",
                columns: new[] { "recipient_user_id", "is_read", "created_at_utc" });

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_Recipient_CreatedAt",
                schema: "notify",
                table: "Notifications",
                columns: new[] { "recipient_user_id", "created_at_utc" });

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_sender_user_id",
                schema: "notify",
                table: "Notifications",
                column: "sender_user_id");

            migrationBuilder.CreateIndex(
                name: "IX_NotifyOutbox_Status_CreatedAt",
                schema: "notify",
                table: "Outbox",
                columns: new[] { "status", "created_at_utc" });

            migrationBuilder.CreateIndex(
                name: "IX_Outbox_notification_id",
                schema: "notify",
                table: "Outbox",
                column: "notification_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.DropTable(
                name: "Outbox",
                schema: "notify");

            migrationBuilder.DropTable(
                name: "Notifications",
                schema: "notify");
        }
    }
}
#pragma warning restore CA1861
