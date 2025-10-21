using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CringeBank.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddAuthAndSocialSchema : Migration
    {
        private static readonly string[] CommentLikesCommentUserIndexColumns = new[] { "comment_id", "user_id" };

        private static readonly string[] DeviceTokensUserTokenIndexColumns = new[] { "user_id", "token" };

        private static readonly string[] FollowsFolloweeCreatedAtIndexColumns = new[] { "followee_user_id", "created_at" };

        private static readonly string[] FollowsFollowerFolloweeIndexColumns = new[] { "follower_user_id", "followee_user_id" };

        private static readonly string[] PostCommentsPostCreatedAtIndexColumns = new[] { "post_id", "created_at" };

        private static readonly string[] PostInteractionsPostUserIndexColumns = new[] { "post_id", "user_id" };

        private static readonly string[] PostsCreatedAtIdIndexColumns = new[] { "created_at", "id" };

        private static readonly string[] PostsUserCreatedAtIndexColumns = new[] { "user_id", "created_at" };

        private static readonly string[] UserBlocksBlockerBlockedIndexColumns = new[] { "blocker_user_id", "blocked_user_id" };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.EnsureSchema(
                name: "social");

            migrationBuilder.EnsureSchema(
                name: "auth");

            migrationBuilder.CreateTable(
                name: "Roles",
                schema: "auth",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    name = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    description = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Roles", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "Tags",
                schema: "social",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    name = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Tags", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                schema: "auth",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    public_id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "NEWSEQUENTIALID()"),
                    email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    email_normalized = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    username = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    username_normalized = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    password_hash = table.Column<byte[]>(type: "varbinary(max)", nullable: true),
                    password_salt = table.Column<byte[]>(type: "varbinary(128)", nullable: true),
                    auth_provider = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false, defaultValue: "sql"),
                    phone = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: true),
                    status = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)1),
                    last_login_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    updated_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "DeviceTokens",
                schema: "auth",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    platform = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    token = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    last_used_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeviceTokens", x => x.id);
                    table.ForeignKey(
                        name: "FK_DeviceTokens_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Follows",
                schema: "auth",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    follower_user_id = table.Column<long>(type: "bigint", nullable: false),
                    followee_user_id = table.Column<long>(type: "bigint", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Follows", x => x.id);
                    table.ForeignKey(
                        name: "FK_Follows_Users_followee_user_id",
                        column: x => x.followee_user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Follows_Users_follower_user_id",
                        column: x => x.follower_user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Posts",
                schema: "social",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    public_id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "NEWSEQUENTIALID()"),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    type = table.Column<byte>(type: "tinyint", nullable: false),
                    text = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    visibility = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)0),
                    likes_count = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    comments_count = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    saves_count = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    updated_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    deleted_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Posts", x => x.id);
                    table.ForeignKey(
                        name: "FK_Posts_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "UserBlocks",
                schema: "auth",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    blocker_user_id = table.Column<long>(type: "bigint", nullable: false),
                    blocked_user_id = table.Column<long>(type: "bigint", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserBlocks", x => x.id);
                    table.ForeignKey(
                        name: "FK_UserBlocks_Users_blocked_user_id",
                        column: x => x.blocked_user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UserBlocks_Users_blocker_user_id",
                        column: x => x.blocker_user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "UserProfiles",
                schema: "auth",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    display_name = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    bio = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    avatar_url = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    banner_url = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    verified = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    location = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    website = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    updated_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserProfiles", x => x.id);
                    table.ForeignKey(
                        name: "FK_UserProfiles_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserRoles",
                schema: "auth",
                columns: table => new
                {
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    role_id = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserRoles", x => new { x.user_id, x.role_id });
                    table.ForeignKey(
                        name: "FK_UserRoles_Roles_role_id",
                        column: x => x.role_id,
                        principalSchema: "auth",
                        principalTable: "Roles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserRoles_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserSecurity",
                schema: "auth",
                columns: table => new
                {
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    otp_secret = table.Column<byte[]>(type: "varbinary(256)", nullable: true),
                    otp_enabled = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    magic_code_hash = table.Column<byte[]>(type: "varbinary(256)", nullable: true),
                    magic_code_expires_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true),
                    refresh_token_hash = table.Column<byte[]>(type: "varbinary(256)", nullable: true),
                    refresh_token_expires_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true),
                    last_password_reset_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserSecurity", x => x.user_id);
                    table.ForeignKey(
                        name: "FK_UserSecurity_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PostComments",
                schema: "social",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    post_id = table.Column<long>(type: "bigint", nullable: false),
                    parent_comment_id = table.Column<long>(type: "bigint", nullable: true),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    text = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    like_count = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    updated_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    deleted_at = table.Column<DateTime>(type: "datetime2(3)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostComments", x => x.id);
                    table.ForeignKey(
                        name: "FK_PostComments_PostComments_parent_comment_id",
                        column: x => x.parent_comment_id,
                        principalSchema: "social",
                        principalTable: "PostComments",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "FK_PostComments_Posts_post_id",
                        column: x => x.post_id,
                        principalSchema: "social",
                        principalTable: "Posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PostComments_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PostLikes",
                schema: "social",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    post_id = table.Column<long>(type: "bigint", nullable: false),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostLikes", x => x.id);
                    table.ForeignKey(
                        name: "FK_PostLikes_Posts_post_id",
                        column: x => x.post_id,
                        principalSchema: "social",
                        principalTable: "Posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PostLikes_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PostMedia",
                schema: "social",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    post_id = table.Column<long>(type: "bigint", nullable: false),
                    url = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    mime = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    width = table.Column<int>(type: "int", nullable: true),
                    height = table.Column<int>(type: "int", nullable: true),
                    order_index = table.Column<byte>(type: "tinyint", nullable: false, defaultValue: (byte)0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostMedia", x => x.id);
                    table.ForeignKey(
                        name: "FK_PostMedia_Posts_post_id",
                        column: x => x.post_id,
                        principalSchema: "social",
                        principalTable: "Posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PostSaves",
                schema: "social",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    post_id = table.Column<long>(type: "bigint", nullable: false),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostSaves", x => x.id);
                    table.ForeignKey(
                        name: "FK_PostSaves_Posts_post_id",
                        column: x => x.post_id,
                        principalSchema: "social",
                        principalTable: "Posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PostSaves_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PostTags",
                schema: "social",
                columns: table => new
                {
                    post_id = table.Column<long>(type: "bigint", nullable: false),
                    tag_id = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostTags", x => new { x.post_id, x.tag_id });
                    table.ForeignKey(
                        name: "FK_PostTags_Posts_post_id",
                        column: x => x.post_id,
                        principalSchema: "social",
                        principalTable: "Posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PostTags_Tags_tag_id",
                        column: x => x.tag_id,
                        principalSchema: "social",
                        principalTable: "Tags",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "CommentLikes",
                schema: "social",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    comment_id = table.Column<long>(type: "bigint", nullable: false),
                    user_id = table.Column<long>(type: "bigint", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CommentLikes", x => x.id);
                    table.ForeignKey(
                        name: "FK_CommentLikes_PostComments_comment_id",
                        column: x => x.comment_id,
                        principalSchema: "social",
                        principalTable: "PostComments",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_CommentLikes_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CommentLikes_user_id",
                schema: "social",
                table: "CommentLikes",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "UX_CommentLikes_Comment_User",
                schema: "social",
                table: "CommentLikes",
                columns: CommentLikesCommentUserIndexColumns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UX_DeviceTokens_User_Token",
                schema: "auth",
                table: "DeviceTokens",
                columns: DeviceTokensUserTokenIndexColumns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Follows_Followee_CreatedAt",
                schema: "auth",
                table: "Follows",
                columns: FollowsFolloweeCreatedAtIndexColumns);

            migrationBuilder.CreateIndex(
                name: "UX_Follows_Follower_Followee",
                schema: "auth",
                table: "Follows",
                columns: FollowsFollowerFolloweeIndexColumns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PostComments_parent_comment_id",
                schema: "social",
                table: "PostComments",
                column: "parent_comment_id");

            migrationBuilder.CreateIndex(
                name: "IX_PostComments_Post_CreatedAt",
                schema: "social",
                table: "PostComments",
                columns: PostCommentsPostCreatedAtIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_PostComments_user_id",
                schema: "social",
                table: "PostComments",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_PostLikes_user_id",
                schema: "social",
                table: "PostLikes",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "UX_PostLikes_Post_User",
                schema: "social",
                table: "PostLikes",
                columns: PostInteractionsPostUserIndexColumns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PostMedia_post_id",
                schema: "social",
                table: "PostMedia",
                column: "post_id");

            migrationBuilder.CreateIndex(
                name: "IX_Posts_CreatedAt_Id",
                schema: "social",
                table: "Posts",
                columns: PostsCreatedAtIdIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_Posts_User_CreatedAt",
                schema: "social",
                table: "Posts",
                columns: PostsUserCreatedAtIndexColumns);

            migrationBuilder.CreateIndex(
                name: "IX_PostSaves_user_id",
                schema: "social",
                table: "PostSaves",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "UX_PostSaves_Post_User",
                schema: "social",
                table: "PostSaves",
                columns: PostInteractionsPostUserIndexColumns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PostTags_tag_id",
                schema: "social",
                table: "PostTags",
                column: "tag_id");

            migrationBuilder.CreateIndex(
                name: "IX_Roles_name",
                schema: "auth",
                table: "Roles",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Tags_name",
                schema: "social",
                table: "Tags",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserBlocks_BlockedUserId",
                schema: "auth",
                table: "UserBlocks",
                column: "blocked_user_id");

            migrationBuilder.CreateIndex(
                name: "UX_UserBlocks_Blocker_Blocked",
                schema: "auth",
                table: "UserBlocks",
                columns: UserBlocksBlockerBlockedIndexColumns,
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UK_UserProfiles_UserId",
                schema: "auth",
                table: "UserProfiles",
                column: "user_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserRoles_role_id",
                schema: "auth",
                table: "UserRoles",
                column: "role_id");

            migrationBuilder.CreateIndex(
                name: "IX_Users_email",
                schema: "auth",
                table: "Users",
                column: "email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_EmailNormalized",
                schema: "auth",
                table: "Users",
                column: "email_normalized",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_username",
                schema: "auth",
                table: "Users",
                column: "username",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Users_UsernameNormalized",
                schema: "auth",
                table: "Users",
                column: "username_normalized",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.DropTable(
                name: "CommentLikes",
                schema: "social");

            migrationBuilder.DropTable(
                name: "DeviceTokens",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "Follows",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "PostLikes",
                schema: "social");

            migrationBuilder.DropTable(
                name: "PostMedia",
                schema: "social");

            migrationBuilder.DropTable(
                name: "PostSaves",
                schema: "social");

            migrationBuilder.DropTable(
                name: "PostTags",
                schema: "social");

            migrationBuilder.DropTable(
                name: "UserBlocks",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "UserProfiles",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "UserRoles",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "UserSecurity",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "PostComments",
                schema: "social");

            migrationBuilder.DropTable(
                name: "Tags",
                schema: "social");

            migrationBuilder.DropTable(
                name: "Roles",
                schema: "auth");

            migrationBuilder.DropTable(
                name: "Posts",
                schema: "social");

            migrationBuilder.DropTable(
                name: "Users",
                schema: "auth");
        }
    }
}
