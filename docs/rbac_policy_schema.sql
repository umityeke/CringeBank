-- CringeBank RBAC Core Schema
-- Generated on 2025-10-06
-- This script seeds the SQL structures needed for the Super Admin governance model.

BEGIN;

CREATE TYPE sa_nom_status AS ENUM ('PENDING','APPROVED','REJECTED','CANCELLED');

CREATE TABLE IF NOT EXISTS roles (
  id           BIGSERIAL PRIMARY KEY,
  name         VARCHAR(64) UNIQUE NOT NULL,
  description  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS permissions (
  id         BIGSERIAL PRIMARY KEY,
  resource   VARCHAR(64) NOT NULL,
  action     VARCHAR(64) NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (resource, action)
);

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id       BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  scope_json    JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS user_roles (
  uid         VARCHAR(128) NOT NULL,
  role_id     BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  status      VARCHAR(16) NOT NULL DEFAULT 'active', -- active, pending, revoked
  scope_json  JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (uid, role_id)
);

CREATE TABLE IF NOT EXISTS claims_versions (
  uid        VARCHAR(128) PRIMARY KEY,
  version    BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS superadmin_nominations (
  id             BIGSERIAL PRIMARY KEY,
  candidate_uid  VARCHAR(128) NOT NULL UNIQUE,
  nominated_by   VARCHAR(128) NOT NULL,
  status         sa_nom_status NOT NULL DEFAULT 'PENDING',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at     TIMESTAMPTZ,
  CHECK (candidate_uid <> nominated_by)
);

CREATE TABLE IF NOT EXISTS superadmin_approvals (
  id             BIGSERIAL PRIMARY KEY,
  nomination_id  BIGINT NOT NULL REFERENCES superadmin_nominations(id) ON DELETE CASCADE,
  approver_uid   VARCHAR(128) NOT NULL,
  decision       BOOLEAN NOT NULL,
  decided_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (nomination_id, approver_uid)
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id            BIGSERIAL PRIMARY KEY,
  actor_uid     VARCHAR(128) NOT NULL,
  action        VARCHAR(128) NOT NULL,
  target_uid    VARCHAR(128),
  metadata      JSONB,
  ip_address    INET,
  user_agent    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed baseline roles
INSERT INTO roles (name, description)
VALUES
  ('superadmin', 'Full-system authority with policy and finance control.'),
  ('admin', 'Delegated operational administrator scoped by policies.'),
  ('category_admin', 'Scoped moderator limited to assigned categories.')
ON CONFLICT (name) DO NOTHING;

-- Sample permissions seed (extend as needed)
INSERT INTO permissions (resource, action, description)
VALUES
  ('users', 'view', 'View user directory'),
  ('users', 'disable', 'Disable user accounts'),
  ('users', 'set_role', 'Assign roles to users'),
  ('vendors', 'approve', 'Approve vendor applications'),
  ('products', 'approve', 'Approve product listings'),
  ('products', 'moderate_content', 'Moderate product content'),
  ('orders', 'release', 'Release escrow for orders'),
  ('cashbox', 'cash_out', 'Perform cash out operations'),
  ('policies', 'role_define', 'Define/update admin roles'),
  ('audit', 'view_all', 'View complete audit trail')
ON CONFLICT (resource, action) DO NOTHING;

COMMIT;
