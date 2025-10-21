using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CringeBank.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddChatSchema : Migration
    {
        private static readonly string[] ConversationMembersUniqueIndexColumns = new[] { "conversation_id", "user_id" };
        private static readonly string[] MessagesConversationIndexColumns = new[] { "conversation_id", "created_at", "id" };
        private static readonly string[] MessageReceiptsUniqueIndexColumns = new[] { "message_id", "user_id", "receipt_type" };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.EnsureSchema(
                name: "chat");

            migrationBuilder.CreateTable(
                name: "Conversations",
                schema: "chat",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    public_id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "NEWSEQUENTIALID()"),
                    is_group = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    title = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    created_by_user_id = table.Column<long>(type: "bigint", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    updated_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Conversations", x => x.id);
                    table.ForeignKey(
                        name: "FK_Conversations_Users_created_by_user_id",
                        column: x => x.created_by_user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ConversationMembers",
                schema: "chat",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    conversation_id = table.Column<long>(type: "bigint", nullable: false),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    role = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)0),
                    joined_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    last_read_message_id = table.Column<long>(type: "bigint", nullable: true),
                    last_read_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConversationMembers", x => x.id);
                    table.ForeignKey(
                        name: "FK_ConversationMembers_Conversations_conversation_id",
                        column: x => x.conversation_id,
                        principalSchema: "chat",
                        principalTable: "Conversations",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ConversationMembers_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Messages",
                schema: "chat",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    conversation_id = table.Column<long>(type: "bigint", nullable: false),
                    sender_user_id = table.Column<long>(type: "bigint", nullable: false),
                    body = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    deleted_for_all = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    edited_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Messages", x => x.id);
                    table.ForeignKey(
                        name: "FK_Messages_Conversations_conversation_id",
                        column: x => x.conversation_id,
                        principalSchema: "chat",
                        principalTable: "Conversations",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Messages_Users_sender_user_id",
                        column: x => x.sender_user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "MessageMedia",
                schema: "chat",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    message_id = table.Column<long>(type: "bigint", nullable: false),
                    url = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    mime = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    width = table.Column<int>(type: "int", nullable: true),
                    height = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MessageMedia", x => x.id);
                    table.ForeignKey(
                        name: "FK_MessageMedia_Messages_message_id",
                        column: x => x.message_id,
                        principalSchema: "chat",
                        principalTable: "Messages",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "MessageReceipts",
                schema: "chat",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    message_id = table.Column<long>(type: "bigint", nullable: false),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    receipt_type = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)0),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MessageReceipts", x => x.id);
                    table.ForeignKey(
                        name: "FK_MessageReceipts_Messages_message_id",
                        column: x => x.message_id,
                        principalSchema: "chat",
                        principalTable: "Messages",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MessageReceipts_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ConversationMembers_conversation_id_user_id",
                schema: "chat",
                table: "ConversationMembers",
                columns: ConversationMembersUniqueIndexColumns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ConversationMembers_user_id",
                schema: "chat",
                table: "ConversationMembers",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_Conversations_created_by_user_id",
                schema: "chat",
                table: "Conversations",
                column: "created_by_user_id");

            migrationBuilder.CreateIndex(
                name: "IX_MessageMedia_message_id",
                schema: "chat",
                table: "MessageMedia",
                column: "message_id");

            migrationBuilder.CreateIndex(
                name: "IX_MessageReceipts_message_id_user_id_receipt_type",
                schema: "chat",
                table: "MessageReceipts",
                columns: MessageReceiptsUniqueIndexColumns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MessageReceipts_user_id",
                schema: "chat",
                table: "MessageReceipts",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_Messages_conversation_id_created_at_id",
                schema: "chat",
                table: "Messages",
                columns: MessagesConversationIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_Messages_sender_user_id",
                schema: "chat",
                table: "Messages",
                column: "sender_user_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.DropTable(
                name: "MessageMedia",
                schema: "chat");

            migrationBuilder.DropTable(
                name: "MessageReceipts",
                schema: "chat");

            migrationBuilder.DropTable(
                name: "Messages",
                schema: "chat");

            migrationBuilder.DropTable(
                name: "ConversationMembers",
                schema: "chat");

            migrationBuilder.DropTable(
                name: "Conversations",
                schema: "chat");
        }
    }
}
