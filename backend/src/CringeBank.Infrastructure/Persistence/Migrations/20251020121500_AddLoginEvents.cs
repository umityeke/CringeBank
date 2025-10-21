using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CringeBank.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddLoginEvents : Migration
    {
        private static readonly string[] LoginEventsUserEventAtIndexColumns = new[] { "user_id", "event_at" };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.EnsureSchema(
                name: "auth");

            migrationBuilder.CreateTable(
                name: "LoginEvents",
                schema: "auth",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<long>(type: "bigint", nullable: true),
                    identifier = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    event_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()"),
                    source = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false, defaultValue: "unknown"),
                    channel = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false, defaultValue: "login"),
                    result = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false, defaultValue: "success"),
                    device_id_hash = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    ip_hash = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                    user_agent = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: true),
                    locale = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: true),
                    time_zone = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    is_trusted_device = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    remember_me = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    requires_device_verification = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTime>(type: "datetime2(3)", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LoginEvents", x => x.id);
                    table.ForeignKey(
                        name: "FK_LoginEvents_Users_user_id",
                        column: x => x.user_id,
                        principalSchema: "auth",
                        principalTable: "Users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_LoginEvents_User_EventAt",
                schema: "auth",
                table: "LoginEvents",
                columns: LoginEventsUserEventAtIndexColumns);

            migrationBuilder.Sql(
                @"CREATE OR ALTER PROCEDURE auth.sp_RecordLoginEvent
    @Identifier NVARCHAR(256),
    @EventAt DATETIME2(3) = NULL,
    @Source NVARCHAR(64) = NULL,
    @Channel NVARCHAR(32) = NULL,
    @Result NVARCHAR(16) = NULL,
    @DeviceIdHash NVARCHAR(128) = NULL,
    @IpHash NVARCHAR(128) = NULL,
    @UserAgent NVARCHAR(512) = NULL,
    @Locale NVARCHAR(16) = NULL,
    @TimeZone NVARCHAR(64) = NULL,
    @IsTrustedDevice BIT = NULL,
    @RememberMe BIT = NULL,
    @RequiresDeviceVerification BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NormalizedIdentifier NVARCHAR(256) = LOWER(@Identifier);
    DECLARE @UserId BIGINT = NULL;

    SELECT TOP (1) @UserId = u.id
    FROM auth.Users AS u
    WHERE u.email = @Identifier
        OR u.username = @Identifier
        OR u.email_normalized = @NormalizedIdentifier
        OR u.username_normalized = @NormalizedIdentifier;

    DECLARE @ResolvedEventAt DATETIME2(3) = ISNULL(@EventAt, SYSUTCDATETIME());
    DECLARE @ResolvedSource NVARCHAR(64) = CASE WHEN NULLIF(@Source, '') IS NULL THEN 'unknown' ELSE @Source END;
    DECLARE @ResolvedChannel NVARCHAR(32) = CASE WHEN NULLIF(@Channel, '') IS NULL THEN 'login' ELSE @Channel END;
    DECLARE @ResolvedResult NVARCHAR(16) = CASE WHEN NULLIF(@Result, '') IS NULL THEN 'success' ELSE @Result END;
    DECLARE @ResolvedTrusted BIT = COALESCE(@IsTrustedDevice, 0);
    DECLARE @ResolvedRememberMe BIT = COALESCE(@RememberMe, 0);
    DECLARE @ResolvedRequiresVerification BIT = COALESCE(@RequiresDeviceVerification, 0);

    INSERT INTO auth.LoginEvents
    (
        user_id,
        identifier,
        event_at,
        source,
        channel,
        result,
        device_id_hash,
        ip_hash,
        user_agent,
        locale,
        time_zone,
        is_trusted_device,
        remember_me,
        requires_device_verification,
        created_at
    )
    VALUES
    (
        @UserId,
        @Identifier,
        @ResolvedEventAt,
        @ResolvedSource,
        @ResolvedChannel,
        @ResolvedResult,
        @DeviceIdHash,
        @IpHash,
        @UserAgent,
        @Locale,
        @TimeZone,
        @ResolvedTrusted,
        @ResolvedRememberMe,
        @ResolvedRequiresVerification,
        SYSUTCDATETIME()
    );

    IF @UserId IS NOT NULL AND @ResolvedResult = 'success'
    BEGIN
        UPDATE auth.Users
        SET last_login_at = @ResolvedEventAt,
            updated_at = SYSUTCDATETIME()
        WHERE id = @UserId;
    END
END");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            ArgumentNullException.ThrowIfNull(migrationBuilder);

            migrationBuilder.Sql(
                "DROP PROCEDURE IF EXISTS auth.sp_RecordLoginEvent;");

            migrationBuilder.DropTable(
                name: "LoginEvents",
                schema: "auth");
        }
    }
}