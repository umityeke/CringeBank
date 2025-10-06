using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CringeBank.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Init : Migration
    {
        private static readonly string[] OrdersBuyerStatusIndexColumns = new[] { "BuyerId", "Status" };
        private static readonly string[] OrdersSellerStatusIndexColumns = new[] { "SellerId", "Status" };
        private static readonly string[] ProductsSellerTypeCategoryIndexColumns = new[] { "SellerType", "Category" };
    private static readonly string[] ProductImagesProductSortOrderIndexColumns = new[] { "ProductId", "SortOrder" };
    private static readonly string[] WalletOwnerKeyTypeIndexColumns = new[] { "OwnerKey", "OwnerType" };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.EnsureSchema(
                name: "cringebank");

            migrationBuilder.CreateTable(
                name: "Products",
                schema: "cringebank",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: false),
                    PriceGold = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Category = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    Condition = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    SellerType = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    SellerId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    VendorId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Products", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Wallets",
                schema: "cringebank",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OwnerKey = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    OwnerType = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    GoldBalance = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false, defaultValue: 0m),
                    CreatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Wallets", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Orders",
                schema: "cringebank",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BuyerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SellerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SellerType = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    PriceGold = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    CommissionGold = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    TotalGold = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    CompletedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CanceledAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CreatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Orders", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Orders_Products_ProductId",
                        column: x => x.ProductId,
                        principalSchema: "cringebank",
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ProductImages",
                schema: "cringebank",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Url = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductImages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProductImages_Products_ProductId",
                        column: x => x.ProductId,
                        principalSchema: "cringebank",
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Escrows",
                schema: "cringebank",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BuyerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SellerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AmountGold = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    ReleasedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    RefundedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CreatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAtUtc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Escrows", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Escrows_Orders_OrderId",
                        column: x => x.OrderId,
                        principalSchema: "cringebank",
                        principalTable: "Orders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Escrows_OrderId",
                schema: "cringebank",
                table: "Escrows",
                column: "OrderId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Escrows_Status",
                schema: "cringebank",
                table: "Escrows",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_Orders_BuyerId_Status",
                schema: "cringebank",
                table: "Orders",
                columns: OrdersBuyerStatusIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_Orders_ProductId",
                schema: "cringebank",
                table: "Orders",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_Orders_SellerId_Status",
                schema: "cringebank",
                table: "Orders",
                columns: OrdersSellerStatusIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_Orders_Status",
                schema: "cringebank",
                table: "Orders",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_ProductImages_ProductId_SortOrder",
                schema: "cringebank",
                table: "ProductImages",
                columns: ProductImagesProductSortOrderIndexColumns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Products_SellerType_Category",
                schema: "cringebank",
                table: "Products",
                columns: ProductsSellerTypeCategoryIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_Products_Status",
                schema: "cringebank",
                table: "Products",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_Wallets_OwnerKey_OwnerType",
                schema: "cringebank",
                table: "Wallets",
                columns: WalletOwnerKeyTypeIndexColumns,
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.DropTable(
                name: "Escrows",
                schema: "cringebank");

            migrationBuilder.DropTable(
                name: "ProductImages",
                schema: "cringebank");

            migrationBuilder.DropTable(
                name: "Wallets",
                schema: "cringebank");

            migrationBuilder.DropTable(
                name: "Orders",
                schema: "cringebank");

            migrationBuilder.DropTable(
                name: "Products",
                schema: "cringebank");
        }
    }
}
