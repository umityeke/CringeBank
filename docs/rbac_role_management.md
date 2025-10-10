# RBAC Role Management Cheat Sheet

This script automates the Firebase custom-claim workflow for `superadmin` and `system_writer` roles. Use it from the `scripts` workspace with Node 18+ and a service account that has permissions to manage Firebase Auth and Firestore.

## 1. One-time setup

1. Enable application default credentials:
   - Export `GOOGLE_APPLICATION_CREDENTIALS` to point at a Firebase service-account JSON that has **Firebase Admin** permissions.
   - Example (PowerShell):

     ```powershell
     $env:GOOGLE_APPLICATION_CREDENTIALS = "C:/secrets/cringebank-admin.json"
     ```

2. Install script dependencies (only needed when switching machines or after a clean checkout):

   ```powershell
   cd scripts
   npm install
   ```

## 2. Supported commands

The script lives at `scripts/access/manage_roles.js`. You can invoke it directly with Node, or via the NPM helper (`npm run access:roles -- <args>`).

### Grant role

```powershell
node access/manage_roles.js grant --email jane@cringebank.dev --role superadmin --notes "Contest jury onboarding"
```

or

```powershell
npm run access:roles -- grant --uid <uid> --role system-writer --notes "Batch import bot"
```

### Revoke role

```powershell
node access/manage_roles.js revoke --uid <uid> --role system-writer --notes "Contract ended"
```

### List role assignments

```powershell
node access/manage_roles.js list
```

Attach `--json` for machine-readable output.

### Dry run (preview)

Add `--dry-run` to validate changes without writing anything:

```powershell
node access/manage_roles.js grant --email jane@cringebank.dev --role superadmin --dry-run
```

## 3. What the script does

- Resolves the Firebase Auth user by `uid` or `email`.
- Updates custom claims for the requested role.
- Mirrors the change into `users/<uid>` in Firestore (`isSuperAdmin`, `roles.superadmin`, `isSystemWriter`, etc.).
- Appends an entry into the `admin_audit` collection with the actor, role, action, and optional notes.
- Prints a reminder that the target user must re-authenticate for new claims to take effect.

These operations keep the Auth claims, Firestore profile, and audit history in sync.

## 4. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `PERMISSION_DENIED` from Firestore | Service account lacks access | Use an admin key with Firestore Admin role |
| `Requested entity was not found` | Wrong UID/email | Double-check spelling or ensure the user exists |
| Claims revert after grant | Another job overwrites custom claims | Audit other automation; ensure merges respect existing values |

## 5. Safety tips

- Always leave a note (`--notes`) when granting elevated access.
- Run with `--dry-run` during audits to confirm the Firestore preview.
- After revoking superadmin, confirm in the dashboard that privileged actions are blocked.
- Keep service-account keys rotated and locked down.
