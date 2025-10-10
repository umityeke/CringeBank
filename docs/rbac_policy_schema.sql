-- CringeBank RBAC Core Schema (SQL Server Edition)
-- Updated on 2025-10-07
-- This script seeds the SQL structures needed for the Super Admin governance model.

CREATE TABLE dbo.roles (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(64) NOT NULL UNIQUE,
    description NVARCHAR(MAX) NULL,
    created_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    updated_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

CREATE TABLE dbo.permissions (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    resource NVARCHAR(64) NOT NULL,
    action NVARCHAR(64) NOT NULL,
    description NVARCHAR(MAX) NULL,
    created_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    updated_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_permissions_resource_action UNIQUE (resource, action)
);
GO

CREATE TABLE dbo.role_permissions (
    role_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    scope_json NVARCHAR(MAX) NULL,
    created_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    updated_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_role_permissions PRIMARY KEY (role_id, permission_id),
    CONSTRAINT FK_role_permissions_role FOREIGN KEY (role_id) REFERENCES dbo.roles(id) ON DELETE CASCADE,
    CONSTRAINT FK_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES dbo.permissions(id) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.user_roles (
    uid NVARCHAR(128) NOT NULL,
    role_id BIGINT NOT NULL,
    status NVARCHAR(16) NOT NULL DEFAULT N'active',
    scope_json NVARCHAR(MAX) NULL,
    created_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    updated_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT PK_user_roles PRIMARY KEY (uid, role_id),
    CONSTRAINT FK_user_roles_role FOREIGN KEY (role_id) REFERENCES dbo.roles(id) ON DELETE CASCADE,
    CONSTRAINT CK_user_roles_status CHECK (status IN (N'active', N'pending', N'revoked'))
);
GO

CREATE TABLE dbo.claims_versions (
    uid NVARCHAR(128) PRIMARY KEY,
    version BIGINT NOT NULL DEFAULT 0,
    updated_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

CREATE TABLE dbo.superadmin_nominations (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    candidate_uid NVARCHAR(128) NOT NULL UNIQUE,
    nominated_by NVARCHAR(128) NOT NULL,
    status NVARCHAR(16) NOT NULL DEFAULT N'PENDING',
    created_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    decided_at DATETIMEOFFSET NULL,
    CONSTRAINT CK_superadmin_nominations_status CHECK (status IN (N'PENDING', N'APPROVED', N'REJECTED', N'CANCELLED')),
    CONSTRAINT CK_superadmin_nominations_candidate_self CHECK (candidate_uid <> nominated_by)
);
GO

CREATE TABLE dbo.superadmin_approvals (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    nomination_id BIGINT NOT NULL,
    approver_uid NVARCHAR(128) NOT NULL,
    decision BIT NOT NULL,
    decided_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
    CONSTRAINT UQ_superadmin_approvals UNIQUE (nomination_id, approver_uid),
    CONSTRAINT FK_superadmin_approvals_nomination FOREIGN KEY (nomination_id) REFERENCES dbo.superadmin_nominations(id) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.audit_logs (
    id BIGINT IDENTITY(1,1) PRIMARY KEY,
    actor_uid NVARCHAR(128) NOT NULL,
    action NVARCHAR(128) NOT NULL,
    target_uid NVARCHAR(128) NULL,
    metadata NVARCHAR(MAX) NULL,
    ip_address VARCHAR(45) NULL,
    user_agent NVARCHAR(MAX) NULL,
    created_at DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET()
);
GO

INSERT INTO dbo.roles (name, description)
SELECT N'superadmin', N'Full-system authority with policy and finance control.'
WHERE NOT EXISTS (SELECT 1 FROM dbo.roles WHERE name = N'superadmin');
GO

INSERT INTO dbo.roles (name, description)
SELECT N'admin', N'Delegated operational administrator scoped by policies.'
WHERE NOT EXISTS (SELECT 1 FROM dbo.roles WHERE name = N'admin');
GO

INSERT INTO dbo.roles (name, description)
SELECT N'category_admin', N'Scoped moderator limited to assigned categories.'
WHERE NOT EXISTS (SELECT 1 FROM dbo.roles WHERE name = N'category_admin');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'users', N'view', N'View user directory'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'users' AND action = N'view');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'users', N'disable', N'Disable user accounts'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'users' AND action = N'disable');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'users', N'set_role', N'Assign roles to users'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'users' AND action = N'set_role');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'vendors', N'approve', N'Approve vendor applications'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'vendors' AND action = N'approve');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'products', N'approve', N'Approve product listings'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'products' AND action = N'approve');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'products', N'moderate_content', N'Moderate product content'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'products' AND action = N'moderate_content');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'orders', N'release', N'Release escrow for orders'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'orders' AND action = N'release');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'cashbox', N'cash_out', N'Perform cash out operations'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'cashbox' AND action = N'cash_out');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'policies', N'role_define', N'Define/update admin roles'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'policies' AND action = N'role_define');
GO

INSERT INTO dbo.permissions (resource, action, description)
SELECT N'audit', N'view_all', N'View complete audit trail'
WHERE NOT EXISTS (SELECT 1 FROM dbo.permissions WHERE resource = N'audit' AND action = N'view_all');
GO
