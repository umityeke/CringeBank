const { Pool } = require('pg');
const functions = require('firebase-functions');

const DEFAULT_TWO_MAN_ACTIONS = new Set([
  'cashbox.cash_out',
  'accounting.adjust',
  'accounting.reconciliation_apply',
  'payouts.process',
  'invoices.cancel',
  'policies.role_define',
]);

class PolicyEvaluator {
  constructor(pool, options = {}) {
    this.pool = pool;
    this.twoManActions = options.twoManActions || DEFAULT_TWO_MAN_ACTIONS;
    this.cacheTtlMs = options.cacheTtlMs || 30_000;
    this.permissionCache = new Map();
  }

  static fromEnv(overrides = {}) {
    const connectionString = overrides.connectionString || process.env.RBAC_DATABASE_URL;

    if (!connectionString) {
      throw new Error('RBAC_DATABASE_URL environment variable is required to instantiate PolicyEvaluator');
    }

    const pool = new Pool({ connectionString, ...overrides.poolConfig });
    return new PolicyEvaluator(pool, overrides.options);
  }

  /**
   * Gracefully close database pool.
   */
  async dispose() {
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
    }
  }

  /**
   * Execute callback with a pooled client, handling release automatically.
   */
  async withClient(callback) {
    const client = await this.pool.connect();
    try {
      return await callback(client);
    } finally {
      client.release();
    }
  }

  /**
   * Fetch the latest claims version stored in SQL for a user.
   */
  async getClaimsVersion(uid) {
    return this.withClient(async (client) => {
      const { rows } = await client.query(
        'SELECT version FROM claims_versions WHERE uid = $1',
        [uid]
      );
      return rows[0]?.version ?? 0;
    });
  }

  /**
   * Retrieve the effective permissions for a user from SQL policies.
   * Caches results briefly to reduce load.
   */
  async listEffectivePermissions(uid) {
    const cacheKey = `perm:${uid}`;
    const cached = this.permissionCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.permissions;
    }

    const permissions = await this.withClient(async (client) => {
      const { rows } = await client.query(
        `SELECT p.resource, p.action, COALESCE(ur.scope_json, rp.scope_json) AS scope
         FROM user_roles ur
         JOIN roles r ON r.id = ur.role_id
         JOIN role_permissions rp ON rp.role_id = r.id
         JOIN permissions p ON p.id = rp.permission_id
         WHERE ur.uid = $1 AND ur.status = 'active'`,
        [uid]
      );
      return rows.map((row) => ({
        key: `${row.resource}.${row.action}`,
        resource: row.resource,
        action: row.action,
        scope: row.scope,
      }));
    });

    this.permissionCache.set(cacheKey, {
      permissions,
      expiresAt: Date.now() + this.cacheTtlMs,
    });

    return permissions;
  }

  /**
   * Determine if a user is allowed to perform a given resource.action.
   * Scope checks are delegated to evaluateScope.
   */
  async isAllowed({ uid, resource, action, scopeContext = {} }) {
    const permissions = await this.listEffectivePermissions(uid);
    const targetKey = `${resource}.${action}`;

    for (const perm of permissions) {
      if (perm.key !== targetKey) continue;
      if (!perm.scope || this.evaluateScope(perm.scope, scopeContext)) {
        return true;
      }
    }

    return false;
  }

  /**
   * Throw an https error if the permission check fails.
   */
  async assertAllowed({ uid, resource, action, scopeContext = {} }) {
    const allowed = await this.isAllowed({ uid, resource, action, scopeContext });
    if (!allowed) {
      throw new functions.https.HttpsError(
        'permission-denied',
        `User ${uid} is not allowed to perform ${resource}.${action}`
      );
    }
  }

  /**
   * Evaluate JSONB scope against runtime context.
   * Extend this method with business-specific logic (categories, vendors, etc.).
   */
  evaluateScope(scope, context) {
    if (!scope) return true;

    if (scope.categories) {
      const allowedCategories = new Set(scope.categories);
      const targetCategory = context.categorySlug;
      if (targetCategory && allowedCategories.has(targetCategory)) {
        return true;
      }
      return false;
    }

    return true;
  }

  /**
   * Check whether the requested action needs two-man approval.
   */
  requiresTwoManApproval(resource, action) {
    return this.twoManActions.has(`${resource}.${action}`);
  }

  /**
   * Nominate a new super admin. Handles bootstrap vs. quorum logic.
   * Returns the resulting nomination record.
   */
  async nominateSuperAdmin({ candidateUid, nominatedBy }) {
    return this.withClient(async (client) => {
      await client.query('BEGIN');
      try {
        const activeCountResult = await client.query(
          `SELECT COUNT(*)::INT AS count
           FROM user_roles ur
           JOIN roles r ON r.id = ur.role_id
           WHERE r.name = 'superadmin' AND ur.status = 'active'`
        );
        const activeSuperAdmins = activeCountResult.rows[0].count;

        if (activeSuperAdmins < 2) {
          await client.query(
            `INSERT INTO user_roles (uid, role_id, status)
             SELECT $1, r.id, 'active'
             FROM roles r WHERE r.name = 'superadmin'
             ON CONFLICT (uid, role_id) DO UPDATE SET status = 'active', updated_at = now()`,
            [candidateUid]
          );

          await client.query(
            `INSERT INTO claims_versions (uid, version, updated_at)
             VALUES ($1, 1, now())
             ON CONFLICT (uid) DO UPDATE SET version = claims_versions.version + 1, updated_at = now()`,
            [candidateUid]
          );

          await client.query('COMMIT');
          return {
            status: 'APPROVED',
            bootstrap: true,
            approvals: 0,
          };
        }

        const nominationResult = await client.query(
          `INSERT INTO superadmin_nominations (candidate_uid, nominated_by)
           VALUES ($1, $2)
           ON CONFLICT (candidate_uid) DO UPDATE SET status = 'PENDING', nominated_by = EXCLUDED.nominated_by, created_at = now()
           RETURNING id, status`,
          [candidateUid, nominatedBy]
        );

        const nomination = nominationResult.rows[0];
        await client.query('COMMIT');
        return nomination;
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    });
  }

  /**
   * Record an approval decision for a nomination.
   * Applies quorum logic and promotes the candidate when threshold met.
   */
  async approveNomination({ nominationId, approverUid, approve }) {
    return this.withClient(async (client) => {
      await client.query('BEGIN');
      try {
        const nominationRes = await client.query(
          `SELECT id, candidate_uid, status FROM superadmin_nominations WHERE id = $1 FOR UPDATE`,
          [nominationId]
        );

        if (nominationRes.rowCount === 0) {
          throw new Error(`Nomination ${nominationId} not found`);
        }

        const nomination = nominationRes.rows[0];
        if (nomination.status !== 'PENDING') {
          await client.query('ROLLBACK');
          return nomination;
        }

        await client.query(
          `INSERT INTO superadmin_approvals (nomination_id, approver_uid, decision)
           VALUES ($1, $2, $3)
           ON CONFLICT (nomination_id, approver_uid) DO UPDATE SET decision = EXCLUDED.decision, decided_at = now()`,
          [nominationId, approverUid, approve]
        );

        if (!approve) {
          await client.query(
            `UPDATE superadmin_nominations
             SET status = 'REJECTED', decided_at = now()
             WHERE id = $1`,
            [nominationId]
          );

          await client.query('COMMIT');
          return { ...nomination, status: 'REJECTED' };
        }

        const approvalRes = await client.query(
          `SELECT COUNT(DISTINCT approver_uid) AS approvals
           FROM superadmin_approvals
           WHERE nomination_id = $1 AND decision = TRUE`,
          [nominationId]
        );

        const approvals = Number(approvalRes.rows[0].approvals);
        if (approvals >= 2) {
          await client.query(
            `UPDATE superadmin_nominations
             SET status = 'APPROVED', decided_at = now()
             WHERE id = $1`,
            [nominationId]
          );

          await client.query(
            `INSERT INTO user_roles (uid, role_id, status)
             SELECT candidate_uid, r.id, 'active'
             FROM superadmin_nominations AS n
             CROSS JOIN roles r
             WHERE n.id = $1 AND r.name = 'superadmin'
             ON CONFLICT (uid, role_id) DO UPDATE SET status = 'active', updated_at = now()`,
            [nominationId]
          );

          await client.query(
            `UPDATE claims_versions
             SET version = version + 1, updated_at = now()
             WHERE uid = (SELECT candidate_uid FROM superadmin_nominations WHERE id = $1)`,
            [nominationId]
          );
        }

        await client.query('COMMIT');
        return { ...nomination, approvals };
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    });
  }
}

module.exports = {
  PolicyEvaluator,
  DEFAULT_TWO_MAN_ACTIONS,
};
