#!/usr/bin/env node

/*
 * RBAC Role Manager
 * ------------------
 * Grants, revokes or lists Firebase custom claims for superadmin and system_writer roles.
 *
 * Usage examples:
 *   node access/manage_roles.js grant --uid <uid> --role superadmin
 *   node access/manage_roles.js grant --email foo@bar.com --role system-writer
 *   node access/manage_roles.js revoke --uid <uid> --role system-writer
 *   node access/manage_roles.js list
 *
 * Requirements:
 *   - GOOGLE_APPLICATION_CREDENTIALS env var pointing to a Firebase service account JSON
 *   - Firestore "users" collection contains a document with the UID
 */

const admin = require('firebase-admin');
const { COMMANDS, normalizeRole, createRoleManager } = require('./role_manager');

if (!admin.apps.length) {
  admin.initializeApp();
}

const roleManager = createRoleManager({
  auth: admin.auth(),
  firestore: admin.firestore(),
  FieldValue: admin.firestore.FieldValue,
});

async function main() {
  const args = parseArgs(process.argv.slice(2));

  switch (args.command) {
    case 'grant':
      await handleApplyRole({ ...args, grant: true });
      break;
    case 'revoke':
      await handleApplyRole({ ...args, grant: false });
      break;
    case 'list':
      await handleListRoles(args);
      break;
    default:
      printHelp();
      process.exit(1);
  }
}

function parseArgs(argv) {
  if (argv.length === 0 || argv.includes('--help') || argv.includes('-h')) {
    printHelp();
    process.exit(0);
  }

  const [command] = argv;

  if (!COMMANDS.has(command)) {
    console.error(`❌ Unknown command: ${command}`);
    printHelp();
    process.exit(1);
  }

  const args = { command };

  for (let i = 1; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--uid') {
      args.uid = argv[++i];
    } else if (token === '--email') {
      args.email = argv[++i];
    } else if (token === '--role') {
      const roleValue = argv[++i];
      try {
        args.role = normalizeRole(roleValue);
      } catch (error) {
        console.error(`❌ ${error.message}`);
        console.error('   Desteklenen roller: superadmin, system-writer');
        process.exit(1);
      }
    } else if (token === '--notes') {
      args.notes = argv[++i];
    } else if (token === '--dry-run') {
      args.dryRun = true;
    } else if (token === '--json') {
      args.json = true;
    } else if (token.startsWith('--')) {
      console.error(`❌ Unknown option: ${token}`);
      printHelp();
      process.exit(1);
    }
  }

  if (args.command === 'list') {
    return args;
  }

  if (!args.role) {
    console.error('❌ --role parametresi gerekli (superadmin | system-writer)');
    process.exit(1);
  }

  if (!args.uid && !args.email) {
    console.error('❌ Kullanıcıyı belirtmek için --uid veya --email parametresi gerekli');
    process.exit(1);
  }

  return args;
}

async function handleApplyRole({ uid, email, role, grant, notes = '', dryRun = false }) {
  const executedBy = process.env.USER || process.env.USERNAME || 'cli.manage_roles';
  const user = await roleManager.resolveUser({ uid, email });
  const targetUid = user.uid;
  const targetEmail = user.email;

  console.log('');
  console.log('⚙️  ROLE MANAGEMENT');
  console.log('────────────────────────────────────────────');
  console.log(`Command : ${grant ? 'grant' : 'revoke'}`);
  console.log(`Role    : ${role}`);
  console.log(`UID     : ${targetUid}`);
  console.log(`Email   : ${targetEmail ?? 'N/A'}`);
  if (notes) {
    console.log(`Notes   : ${notes}`);
  }
  if (dryRun) {
    console.log('Mode    : DRY RUN (changes will not be saved)');
  }
  console.log('────────────────────────────────────────────');

  const summary = await roleManager.applyRole({
    uid: targetUid,
    email: targetEmail,
    role,
    grant,
    notes,
    dryRun,
    executedBy,
    user,
  });

  if (dryRun) {
    console.log('New custom claims preview:', summary.newClaims);
    console.log('Firestore updates preview:', summary.firestoreUpdates);
    console.log('Audit log preview:', summary.auditEntry);
    console.log('');
    return;
  }

  console.log('✅ Custom claims updated');
  console.log('✅ Firestore user document updated');
  console.log('✅ Audit log entry created');
  console.log('');
  console.log('ℹ️  Kullanıcının claim değişikliklerinin geçerli olması için tekrar oturum açması gerekir.');
  console.log('');
}

async function handleListRoles({ json = false }) {
  console.log('');
  console.log('🔍 Listing users with superadmin/system_writer claims...');
  console.log('');

  const result = await roleManager.listRoles();

  if (result.length === 0) {
    console.log('No users found with these roles.');
    return;
  }

  if (json) {
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  for (const entry of result) {
    console.log('────────────────────────────────────────────');
    console.log(`UID   : ${entry.uid}`);
    console.log(`Email : ${entry.email || 'N/A'}`);
    console.log(`Name  : ${entry.displayName || 'N/A'}`);
    console.log('Claims:');
    console.log(`  superadmin    : ${entry.claims.superadmin}`);
    console.log(`  system_writer : ${entry.claims.system_writer}`);
    console.log(`  admin         : ${entry.claims.admin}`);
    console.log(`  backend       : ${entry.claims.backend}`);
    console.log(`  role          : ${entry.claims.role || '—'}`);
  }
  console.log('────────────────────────────────────────────');
  console.log(`Total: ${result.length}`);
}

function printHelp() {
  console.log('');
  console.log('RBAC Role Manager');
  console.log('────────────────────────────────────────────');
  console.log('Usage:');
  console.log('  node access/manage_roles.js grant  --uid <uid> [--role superadmin|system-writer] [--notes "reason"]');
  console.log('  node access/manage_roles.js revoke --email <email> --role system-writer');
  console.log('  node access/manage_roles.js list [--json]');
  console.log('');
  console.log('Options:');
  console.log('  --uid <uid>          Firebase Authentication UID');
  console.log('  --email <email>      Email address to resolve UID');
  console.log('  --role <role>        Target role (superadmin, system-writer)');
  console.log('  --notes <text>       Extra note stored in admin_audit');
  console.log('  --dry-run            Do not persist changes, only show preview');
  console.log('  --json               When listing, output JSON instead of text');
  console.log('');
  console.log('Environment: GOOGLE_APPLICATION_CREDENTIALS must point to a service account key.');
  console.log('');
}

if (require.main === module) {
  main().catch((error) => {
    console.error('');
    console.error('❌ Operation failed:', error.message);
    console.error(error);
    process.exit(1);
  });
}

module.exports = {
  main,
  parseArgs,
  handleApplyRole,
  handleListRoles,
  printHelp,
};
