using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CringeBank.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddWalletSchema : Migration
    {
        private static readonly string[] s_inAppPurchaseIndexColumns = ["account_id", "status"];
        private static readonly string[] s_transactionIndexColumns = ["account_id", "created_at"];

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.EnsureSchema(
                name: "wallet");

            migrationBuilder.CreateTable(
                name: "Accounts",
                schema: "wallet",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    balance = table.Column<decimal>(type: "decimal(18,2)", nullable: false, defaultValue: 0m),
                    currency = table.Column<string>(type: "nvarchar(3)", maxLength: 3, nullable: false, defaultValue: "CG"),
                    updated_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Accounts", x => x.id);
                    table.ForeignKey(
                        name: "FK_Accounts_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "InAppPurchases",
                schema: "wallet",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    account_id = table.Column<long>(type: "bigint", nullable: false),
                    platform = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    receipt = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    status = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)0),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    validated_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InAppPurchases", x => x.id);
                    table.ForeignKey(
                        name: "FK_InAppPurchases_Accounts_account_id",
                        column: x => x.account_id,
                        principalSchema: "wallet",
                        principalTable: "Accounts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Transactions",
                schema: "wallet",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    account_id = table.Column<long>(type: "bigint", nullable: false),
                    external_id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "NEWSEQUENTIALID()"),
                    type = table.Column<byte>(type: "tinyint", nullable: false),
                    amount = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    balance_after = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    reference = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    metadata = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Transactions", x => x.id);
                    table.ForeignKey(
                        name: "FK_Transactions_Accounts_account_id",
                        column: x => x.account_id,
                        principalSchema: "wallet",
                        principalTable: "Accounts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "TransferAudits",
                schema: "wallet",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    from_account_id = table.Column<long>(type: "bigint", nullable: true),
                    to_account_id = table.Column<long>(type: "bigint", nullable: true),
                    amount = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    status = table.Column<byte>(type: "tinyint", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TransferAudits", x => x.id);
                    table.ForeignKey(
                        name: "FK_TransferAudits_Accounts_from_account_id",
                        column: x => x.from_account_id,
                        principalSchema: "wallet",
                        principalTable: "Accounts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TransferAudits_Accounts_to_account_id",
                        column: x => x.to_account_id,
                        principalSchema: "wallet",
                        principalTable: "Accounts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "UX_Accounts_user_id",
                schema: "wallet",
                table: "Accounts",
                column: "user_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_InAppPurchases_account_id_status",
                schema: "wallet",
                table: "InAppPurchases",
                columns: s_inAppPurchaseIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_account_id_created_at",
                schema: "wallet",
                table: "Transactions",
                columns: s_transactionIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_TransferAudits_created_at",
                schema: "wallet",
                table: "TransferAudits",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "IX_TransferAudits_from_account_id",
                schema: "wallet",
                table: "TransferAudits",
                column: "from_account_id");

            migrationBuilder.CreateIndex(
                name: "IX_TransferAudits_to_account_id",
                schema: "wallet",
                table: "TransferAudits",
                column: "to_account_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.DropTable(
                name: "InAppPurchases",
                schema: "wallet");

            migrationBuilder.DropTable(
                name: "Transactions",
                schema: "wallet");

            migrationBuilder.DropTable(
                name: "TransferAudits",
                schema: "wallet");

            migrationBuilder.DropTable(
                name: "Accounts",
                schema: "wallet");
        }
    }
}
