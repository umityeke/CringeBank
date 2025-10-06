# CringeBank Admin RBAC & Governance Specification

## 1. Overview

This document formalizes the role-based access control (RBAC) model, the two-man governance rule for super admin appointments, and the supporting data structures required to operate the CringeBank Super Admin and Admin panels. It is the single source of truth for backend, frontend, and DevOps teams.

---

## 2. Core Roles

| Role             | Description |
|------------------|-------------|
| `superadmin`     | Full-system authority. Manages policies, roles, finance workflows, critical toggles, and the entire admin panel landscape. |
| `admin`          | Delegated authority defined by super admin policy. Typically covers catalog, vendor operations, and limited reporting. |
| `category_admin` | Scoped moderator for specific product categories. Permissions are limited to the assigned scope. |

Super admins can appoint other super admins. The first two super admins are immediately active (bootstrap). Every super admin beyond the first two requires approval from at least two distinct active super admins. Demotion/ban of a super admin also requires two approvals.

---

## 3. Permission Taxonomy

Permissions are defined as `(resource, action)` pairs. Example taxonomy:

```text
users.view, users.disable, users.set_role, users.mask_pii
vendors.view, vendors.approve, vendors.reject, vendors.suspend
products.view, products.approve, products.archive, products.feature, products.moderate_content
orders.view, orders.release, orders.refund, disputes.resolve
ledger.view_summary, ledger.view_detail_masked, ledger.view_detail_full, ledger.export
accounting.view, accounting.post_manual, accounting.adjust, accounting.reconciliation_run, accounting.reconciliation_apply
invoices.view, invoices.issue, invoices.cancel
cashbox.view, cashbox.cash_in, cashbox.cash_out, cashbox.two_man_rule_bypass
payouts.view, payouts.schedule, payouts.process
market_config.category_crud, market_config.commission_set, market_config.allowlist_set
system.maintenance_toggle, system.appcheck_view, system.functions_health, system.keys_view
policies.role_define, policies.permission_grant, policies.permission_revoke
audit.view_all, audit.export, audit.impersonate_view
```

Super admins own the default mapping of permissions to admin roles. Category admins inherit only scoped product moderation permissions.

---

## 4. SQL Schema

### 4.1 Roles & Permissions

```sql
CREATE TABLE roles (
  id           BIGSERIAL PRIMARY KEY,
  name         VARCHAR(64) UNIQUE NOT NULL,
  description  TEXT
);

CREATE TABLE permissions (
  id         BIGSERIAL PRIMARY KEY,
  resource   VARCHAR(64) NOT NULL,
  action     VARCHAR(64) NOT NULL,
  UNIQUE (resource, action)
);

CREATE TABLE role_permissions (
  role_id      BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  scope_json   JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);

CREATE INDEX idx_role_permissions_scope ON role_permissions USING GIN (scope_json);
```

`scope_json` encodes constrained contexts, e.g. `{"categories": ["digital","fashion"]}` for category admins.

### 4.2 User Roles & Claims Version

```sql
CREATE TABLE user_roles (
  uid         VARCHAR(128) NOT NULL,
  role_id     BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  status      VARCHAR(16) NOT NULL DEFAULT 'active', -- 'active','pending','revoked'
  scope_json  JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (uid, role_id)
);

CREATE INDEX idx_user_roles_status ON user_roles(uid, status);

CREATE TABLE claims_versions (
  uid         VARCHAR(128) PRIMARY KEY,
  version     BIGINT NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

`claims_versions.version` increments every time a user’s policy set changes. The Firebase custom claim mirrors this value, forcing clients to refresh tokens when mismatched.

### 4.3 Super Admin Nomination Workflow

```sql
CREATE TYPE sa_nom_status AS ENUM ('PENDING','APPROVED','REJECTED','CANCELLED');

CREATE TABLE superadmin_nominations (
  id             BIGSERIAL PRIMARY KEY,
  candidate_uid  VARCHAR(128) NOT NULL UNIQUE,
  nominated_by   VARCHAR(128) NOT NULL,
  status         sa_nom_status NOT NULL DEFAULT 'PENDING',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at     TIMESTAMPTZ,
  CHECK (candidate_uid <> nominated_by)
);

CREATE TABLE superadmin_approvals (
  id             BIGSERIAL PRIMARY KEY,
  nomination_id  BIGINT NOT NULL REFERENCES superadmin_nominations(id) ON DELETE CASCADE,
  approver_uid   VARCHAR(128) NOT NULL,
  decision       BOOLEAN NOT NULL, -- TRUE approve, FALSE reject
  decided_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (nomination_id, approver_uid),
  CHECK (decision IN (TRUE, FALSE))
);

CREATE INDEX idx_superadmin_approvals_nom ON superadmin_approvals(nomination_id);
```

### 4.4 Audit Logging

```sql
CREATE TABLE audit_logs (
  id            BIGSERIAL PRIMARY KEY,
  actor_uid     VARCHAR(128) NOT NULL,
  action        VARCHAR(128) NOT NULL,
  target_uid    VARCHAR(128),
  metadata      JSONB,
  ip_address    INET,
  user_agent    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_uid);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
```

Important audit events include nominations, approvals, demotions, permission grants/revocations, and all critical finance operations.

---

## 5. Bootstrap Rules

1. Seed `roles` table with `superadmin`, `admin`, and `category_admin`.
2. Insert baseline permissions and mappings for default admin experiences.
3. Populate the first two super admins directly in `user_roles` as `status='active'` and set their `claims_versions` to `1`.
4. Do not expose the Super Admin panel until at least one super admin exists.

---

## 6. Two-Man Rule Logic

### Appointment

1. **Nominate**: Active super admin submits a nomination. If current active count `< 2`, the candidate is promoted instantly (status `active`). Otherwise, the nomination remains `PENDING` and creates a `user_roles` row with `status='pending'`.
2. **Approve/Reject**: Distinct active super admins cast decisions. Two approvals → promotion becomes active. Any rejection → nomination set to `REJECTED`, pending role removed.
3. **Self-check**: Candidate cannot approve their own nomination.

### Demotion

Demotion or banning of a super admin uses the same approval flow: a nomination-like request for removal, requiring two distinct approvals. Upon approval, the `user_roles` status becomes `revoked`, claims version increments, and the Firebase token is invalidated.

---

## 7. Token Synchronization

1. Policy change triggers `claims_versions.version = version + 1` for the affected user.
2. Admin SDK updates Firebase custom claims: `{ "roles": [...], "claims_version": <version> }`.
3. Backend middleware compares token `claims_version` to SQL. Mismatch → HTTP 409; client must refresh token via `getIdToken(true)`.

---

## 8. API Guard Sequence

1. Verify Firebase ID token (aud/iss/exp, `email_verified = TRUE`).
2. Fetch latest SQL `claims_version` for `uid`; enforce match.
3. Evaluate policy: `isAllowed(uid, resource, action, scope)`.
4. Enforce domain-specific conditions (e.g. category scope, order state machine).
5. Execute business logic.

---

## 9. Firestore & Cloud Functions

- Sensitive writes (finance, policy management) run exclusively through Cloud Functions with SQL-backed verification.
- Firestore rules rely on custom claims only for read gating (e.g., allow super admins to fetch system diagnostics).
- Admin panel Firestore collections should never store critical finance states without SQL consensus.

---

## 10. Frontend Considerations

### Super Admin Panel (full menu)

- Dashboard, Users, Vendors, Products, Orders/Escrow, Disputes, Accounting, Invoices, Cashbox, Payouts, Market Config, System Settings, Policies & Roles, Audit/Logs.
- Provide nomination screens, approval queues, two-man approval banners for finance operations, and scope management UI.

### Normal Admin Panel

- Menu auto-generated from allowed actions.
- PII masked where appropriate. Critical finance pages hidden.
- Dispute resolution limited to suggestions.

---

## 11. Enhancements (Optional)

- Two-man rule scheduler (expiry for pending approvals).
- Permission presets (Operational Admin, Catalog Admin, Support Admin).
- Simulation mode: preview a user’s allowed actions without switching accounts.
- Temporary (time-boxed) permissions with auto-expiry policies.

---

## 12. Acceptance Checklist

- [ ] Bootstrap seeds create two active super admins successfully.
- [ ] Third super admin cannot become active without two distinct approvals.
- [ ] Candidate cannot approve their own nomination.
- [ ] Demotions require two approvals and revoke claims immediately.
- [ ] Token mismatch returns 409 until refreshed.
- [ ] Critical finance actions enforce two-man approvals.
- [ ] Every nomination/approval/demotion/critical finance action generates an audit log.

---

## 13. References

- Firebase Admin SDK custom claims documentation.
- OWASP Access Control Cheat Sheet (for least privilege best practices).
- CringeBank existing services (`UserService`, `CringeEntryService`) for integration guidance.
