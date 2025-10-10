# Admin Badges & Verification Plan

Updated: 2025-10-09

## Objectives

- Model badges, verification requests, admin roles, and audit logs in SQL.
- Expose secure callable procedures for admin operations.
- Extend Flutter admin panel with badge and verification management screens.
- Record every moderation action to an immutable audit trail.
- Validate with automated tests covering RBAC, workflows, and logging.

## Data Model Overview

| Table | Purpose | Key Columns |
| --- | --- | --- |
| `dbo.Badges` | Master list of badge definitions. | `BadgeId (PK, bigint identity)`, `Slug (nvarchar(64) unique)`, `Title`, `Description`, `IconUrl`, `IsActive`, `CreatedAt`, `UpdatedAt`, `CreatedByAuthUid`, `UpdatedByAuthUid` |
| `dbo.UserBadges` | User-to-badge assignments. | `UserBadgeId (PK)`, `AuthUid` (FK to users), `BadgeId` (FK to badges), `GrantedAt`, `GrantedByAuthUid`, `RevokedAt`, `RevokedByAuthUid`, `Reason`, unique index on `(AuthUid, BadgeId, RevokedAt)` to allow only one active assignment |
| `dbo.VerificationRequests` | User verification workflow. | `RequestId (PK)`, `AuthUid`, `Status` (`pending/approved/rejected`), `SubmittedAt`, `ReviewedAt`, `ReviewedByAuthUid`, `ReviewNotes`, `AttachmentsJson`, `DecisionMetadataJson` |
| `dbo.AdminRoles` | SQL-backed admin role assignments. | `AdminRoleId (PK)`, `AuthUid`, `RoleKey`, `Status`, `ScopeJson`, `GrantedAt`, `GrantedByAuthUid`, `RevokedAt`, `RevokedByAuthUid` |
| `dbo.AdminAuditLog` | Append-only moderation events. | `AuditId (PK)`, `OccurredAt`, `ActorAuthUid`, `TargetAuthUid`, `Action`, `EntityType`, `EntityId`, `PayloadJson`, `IpAddress`, `UserAgent`, index on `OccurredAt DESC` |

All tables include `RowVersion` (`rowversion`) for optimistic concurrency and are clustered on the primary key.

## Stored Procedure Set

### Badge Management

- `dbo.sp_Admin_CreateBadge` – insert badge definition, ensuring unique slug.
- `dbo.sp_Admin_UpdateBadge` – update metadata, audit change.
- `dbo.sp_Admin_ListBadges` – optional filters (`isActive`, search by slug/title).
- `dbo.sp_Admin_AssignBadge` – ensure badge active, create or reactivate `UserBadges` row, emit audit log.
- `dbo.sp_Admin_RevokeBadge` – mark `RevokedAt`, `RevokedByAuthUid`, emit audit log.

### Verification Workflow

- `dbo.sp_Admin_SubmitVerificationRequest` – called by app when user submits (stores attachments, sets pending).
- `dbo.sp_Admin_ListVerificationRequests` – list filtered by status, pagination parameters.
- `dbo.sp_Admin_ReviewVerificationRequest` – update status to approved/rejected, set reviewer info, audit log.

### Admin Roles

- `dbo.sp_Admin_ListRoles` – list available role assignments per user.
- `dbo.sp_Admin_AssignRole` – grant role (insert row), support scopes.
- `dbo.sp_Admin_RevokeRole` – revoke existing row.

### Audit Helper

- `dbo.sp_Admin_LogAudit` – generic insert used internally (badge/verification/role procedures call via transaction).

## Firebase Functions Integration

Add callable definitions to `functions/sql_gateway/procedures.js`:

- `adminBadgeList`, `adminBadgeUpsert`, `adminBadgeAssign`, `adminBadgeRevoke`
- `adminVerificationList`, `adminVerificationReview`
- `adminRoleList`, `adminRoleAssign`, `adminRoleRevoke`

Each procedure requires App Check, enforces RBAC via `resource`/`action` pairs (`admin.badge`, `admin.verification`, `admin.role`). `scopeContextBuilder` returns affected user ID(s) for audit trails. After each SQL execution, wrap result with metadata for UI.

Implement reusable helper `logAdminAudit` under `functions/admin_audit.js` that inserts into `AdminAuditLog` using the stored procedure.

## Flutter Admin Panel Enhancements

- Create services in `lib/services/admin_badge_service.dart` and `lib/services/admin_verification_service.dart` that call new callables, convert DTOs to Dart models.
- Add new models: `AdminBadge`, `AdminVerificationRequest`, `AdminAuditEntry` (if needed for playback).
- Extend `AdminMenuCatalog` with two entries: “Rozet Yönetimi” and “Doğrulama Talepleri”.
- Build UI pages under `lib/screens/admin/badges/` and `lib/screens/admin/verification/` with list/detail views, approve/reject dialogs, assignment forms.
- Guard menus based on `User.adminRoles`/`grantedPermissions` (`superadmin`, `admin_badges`, `admin_verification`).

## Automation & Logging

- Every callable writes an audit record (`action`, `entityType`, `entityId`, diff payload, IP/user agent from context if available).
- Optionally add background job to expire stale verification requests (future enhancement, not MVP).

## Validation Strategy

- **SQL Tests**: Use Jest with `mssql` mock to verify binding/transform logic; integration tests can rely on local SQL container later.
- **Flutter Tests**: Widget tests for admin pages (loading, success, error states). Unit tests verifying service parsing and permission gating.
- **Manual Checklist**: Create badge, assign to user, review verification request, check `AdminAuditLog` row; attempt unauthorized call to confirm RBAC failure.
- **Docs**: Update README or new `docs/admin_workflows_status.md` with deployment instructions and feature flags.

## Rollout Steps

1. Apply migration script via sqlcmd (add to CI pipeline).
2. Deploy Firebase Functions after adding new callables and audit helper.
3. Enable feature flags/custom claims for pilot admin users.
4. Validate audit log ingestion and UI flows on staging before prod.
