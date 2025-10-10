# RBAC Onboarding Guide

## Overview

The CringeBank backend uses Role-Based Access Control (RBAC) to authorize SQL operations. Custom Firebase Auth claims assign roles to users, and the SQL Gateway enforces permissions before executing stored procedures.

## Role Hierarchy

| Role           | Description                                           | Permissions                                      |
|----------------|-------------------------------------------------------|--------------------------------------------------|
| `user`         | Default authenticated user                            | Read own data, standard operations               |
| `system_writer`| Backend service account / elevated client operations  | Write operations, escrow release, wallet adjust  |
| `superadmin`   | Full database access for admin panel                  | All operations, badge management, audit logs     |

## Assigning Roles

### Via Script (Recommended)

```bash
cd functions
node scripts/assign_role.js assign <uid> <role>
```

**Examples:**

```bash
# Assign system_writer role
node scripts/assign_role.js assign abc123def456 system_writer

# Assign superadmin role
node scripts/assign_role.js assign abc123def456 superadmin

# Revoke elevated role (reset to user)
node scripts/assign_role.js revoke abc123def456

# List current roles
node scripts/assign_role.js list abc123def456 xyz789ghi012
```

### Via Firebase Admin SDK

```javascript
const admin = require('firebase-admin');

await admin.auth().setCustomUserClaims(uid, {
  role: 'system_writer',
  assignedAt: new Date().toISOString(),
});
```

### Via Firebase Console

1. Navigate to **Authentication** > **Users**
2. Click on user email/UID
3. Scroll to **Custom claims**
4. Add JSON:
   ```json
   {
     "role": "system_writer"
   }
   ```
5. Save changes

**Note:** Custom claims changes require user to re-authenticate (refresh ID token) to take effect.

## Verifying Role Assignment

### Client-Side (Flutter)

```dart
final user = FirebaseAuth.instance.currentUser;
final idTokenResult = await user?.getIdTokenResult();
final role = idTokenResult?.claims?['role'] ?? 'user';

print('Current role: $role');
```

### Server-Side (Cloud Functions)

```javascript
exports.myFunction = functions.https.onCall((data, context) => {
  const role = context.auth?.token?.role || 'user';
  console.log(`User role: ${role}`);
});
```

### Via Script

```bash
node scripts/assign_role.js list <uid>
```

## SQL Gateway Integration

Each stored procedure registered in `sql_gateway/procedures.js` specifies required roles:

```javascript
{
  adjustWalletBalance: {
    procedure: 'sp_Store_AdjustWalletBalance',
    params: { /* ... */ },
    roles: ['system_writer', 'superadmin'], // Only these roles allowed
  }
}
```

When a client calls `sqlGatewayAdjustWalletBalance`, the gateway:

1. Extracts `role` from Firebase Auth ID token
2. Checks if `role` is in allowed `roles` array
3. Rejects with `permission-denied` if unauthorized
4. Executes procedure if authorized

## Common Scenarios

### Backend Service Account

Create a service account in Firebase Console with `system_writer` role for automated operations (cron jobs, admin scripts):

```bash
# Assign role after creating service account
node scripts/assign_role.js assign <service_account_uid> system_writer
```

### Admin Panel User

Assign `superadmin` to trusted admin users who need full database access:

```bash
node scripts/assign_role.js assign <admin_uid> superadmin
```

### Revoking Access

Reset user to default `user` role:

```bash
node scripts/assign_role.js revoke <uid>
```

Or manually set claims to `null`:

```javascript
await admin.auth().setCustomUserClaims(uid, null);
```

## Security Best Practices

1. **Principle of Least Privilege**
   - Only assign elevated roles when absolutely necessary
   - Regularly audit role assignments

2. **Service Account Isolation**
   - Use dedicated Firebase projects for service accounts
   - Rotate service account keys periodically

3. **Token Refresh**
   - Client apps must refresh ID token after role changes
   - Force sign-out/sign-in for immediate effect

4. **Audit Logging**
   - All superadmin operations are logged via `sp_Admin_LogAudit`
   - Review audit logs regularly for suspicious activity

5. **Environment Separation**
   - Use separate Firebase projects for dev/staging/prod
   - Never assign superadmin in dev environment with prod credentials

## Troubleshooting

### Permission Denied Errors

```
code: permission-denied
message: Insufficient permissions. Required roles: system_writer
```

**Solution:**
1. Verify role assignment: `node scripts/assign_role.js list <uid>`
2. Ensure user has refreshed ID token
3. Check procedure's `roles` array in `sql_gateway/procedures.js`

### Role Not Taking Effect

**Cause:** ID token not refreshed after claim update

**Solution:**
```dart
// Force token refresh
await FirebaseAuth.instance.currentUser?.getIdToken(true);
```

Or sign out and sign back in.

### SQL Connection Failed

**Cause:** Database credentials missing or invalid

**Solution:**
1. Check `functions/.env` for `SQL_SERVER`, `SQL_USER`, `SQL_PASSWORD`
2. Verify SQL Server firewall allows Cloud Functions IP ranges
3. Test connection with `sqlcmd` from local machine

## Migration Checklist

When migrating Firestore operations to SQL Gateway:

- [ ] Create stored procedure in `backend/scripts/stored_procedures/`
- [ ] Register procedure in `sql_gateway/procedures.js` with appropriate roles
- [ ] Update Flutter service to call new `sqlGateway<Procedure>` function
- [ ] Assign roles to service accounts / admin users
- [ ] Test with different role assignments (user, system_writer, superadmin)
- [ ] Monitor Cloud Functions logs for permission errors
- [ ] Document required role in Flutter service method comments

## References

- [Firebase Custom Claims](https://firebase.google.com/docs/auth/admin/custom-claims)
- [Cloud Functions HTTPS Callable](https://firebase.google.com/docs/functions/callable)
- [SQL Gateway README](./sql_gateway/README_GATEWAY.md)
- [Admin Operations](./adminOps.js)

---

**Last Updated:** October 9, 2025
