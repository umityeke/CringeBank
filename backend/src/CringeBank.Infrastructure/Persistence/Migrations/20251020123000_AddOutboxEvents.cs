using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CringeBank.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddOutboxEvents : Migration
    {
        private static readonly string[] OutboxEventsStatusCreatedAtIndexColumns = new[] { "status", "created_at" };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.EnsureSchema(
                name: "outbox");

            migrationBuilder.CreateTable(
                name: "Events",
                schema: "outbox",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    topic = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    payload = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    status = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)0),
                    retries = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    processed_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Events", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_OutboxEvents_Status",
                schema: "outbox",
                table: "Events",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "IX_OutboxEvents_Status_CreatedAt",
                schema: "outbox",
                table: "Events",
                columns: OutboxEventsStatusCreatedAtIndexColumns);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.DropTable(
                name: "Events",
                schema: "outbox");
        }
    }
}
