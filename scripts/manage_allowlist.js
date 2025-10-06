#!/usr/bin/env node
/**
 * Manage external media allowlist document.
 * Usage examples:
 *   node scripts/manage_allowlist.js --list
 *   node scripts/manage_allowlist.js --add imgur.com i.imgur.com
 *   node scripts/manage_allowlist.js --remove badhost.com
 *   node scripts/manage_allowlist.js --add example.com --description "Özel alan eklendi"
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const docRef = db.collection('config').doc('allowedMediaHosts');

const normalizeHosts = (chunks) => {
  return chunks
    .flatMap((chunk) => String(chunk).split(','))
    .map((host) => host.trim().toLowerCase())
    .filter(Boolean);
};

const parseArguments = () => {
  const args = process.argv.slice(2);
  const operations = {
    add: [],
    remove: [],
    list: false,
    description: null,
    help: false,
  };

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];

    switch (arg) {
      case '--add':
      case '-a': {
        const collect = [];
        i += 1;
        while (i < args.length && !args[i].startsWith('-')) {
          collect.push(args[i]);
          i += 1;
        }
        i -= 1;
        operations.add.push(...normalizeHosts(collect));
        break;
      }
      case '--remove':
      case '-r': {
        const collect = [];
        i += 1;
        while (i < args.length && !args[i].startsWith('-')) {
          collect.push(args[i]);
          i += 1;
        }
        i -= 1;
        operations.remove.push(...normalizeHosts(collect));
        break;
      }
      case '--list':
      case '-l':
        operations.list = true;
        break;
      case '--description':
      case '-d':
        if (i + 1 >= args.length || args[i + 1].startsWith('-')) {
          throw new Error('--description parametresi için bir değer sağlamalısınız.');
        }
        operations.description = args[++i];
        break;
      case '--help':
      case '-h':
        operations.help = true;
        break;
      default:
        console.warn(`Bilinmeyen argüman atlandı: ${arg}`);
        break;
    }
  }

  return operations;
};

const printUsage = () => {
  console.log(`
Harici medya allowlist yönetimi:
  --list, -l                Şu anki domain listesini görüntüler
  --add, -a <domain...>     Listeye domain ekler (boşluk veya virgül ile ayırabilirsiniz)
  --remove, -r <domain...>  Listeden domain çıkarır
  --description, -d <text>  Açıklama alanını günceller
  --help, -h                Bu mesajı gösterir

Örnek:
  node scripts/manage_allowlist.js --add imgur.com i.imgur.com
  node scripts/manage_allowlist.js --remove badhost.com --description "Temizlik"
`);
};

const loadAllowlist = async () => {
  const snapshot = await docRef.get();
  if (!snapshot.exists) {
    return {
      hosts: [],
      description: '',
    };
  }

  const data = snapshot.data() || {};
  const hosts = Array.isArray(data.hosts) ? data.hosts.map((host) => String(host).trim().toLowerCase()).filter(Boolean) : [];

  return {
    hosts,
    description: typeof data.description === 'string' ? data.description : '',
  };
};

const saveAllowlist = async ({ hosts, description }) => {
  const payload = {
    hosts,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: process.env.ALLOWLIST_UPDATED_BY || 'cli',
  };

  if (typeof description === 'string') {
    payload.description = description;
  }

  await docRef.set(payload, { merge: true });
};

const main = async () => {
  try {
    const operations = parseArguments();

    if (operations.help || (!operations.list && operations.add.length === 0 && operations.remove.length === 0 && operations.description == null)) {
      printUsage();
      if (!operations.help) {
        console.log('En az bir işlem belirtmelisiniz.');
      }
      process.exit(0);
    }

    const current = await loadAllowlist();
    const hostSet = new Set(current.hosts);

    operations.add.forEach((host) => hostSet.add(host));
    operations.remove.forEach((host) => hostSet.delete(host));

    const updatedHosts = Array.from(hostSet).sort((a, b) => a.localeCompare(b));
    const description = operations.description != null ? operations.description : current.description;

    if (operations.add.length > 0 || operations.remove.length > 0 || operations.description != null) {
      await saveAllowlist({ hosts: updatedHosts, description });
      console.log('✅ Allowlist güncellendi.');
    }

    if (operations.list || operations.add.length > 0 || operations.remove.length > 0) {
      const latest = operations.add.length > 0 || operations.remove.length > 0 || operations.description != null
        ? updatedHosts
        : current.hosts;

      console.log('\n📋 Mevcut domainler:');
      latest.forEach((host, index) => {
        console.log(`  ${index + 1}. ${host}`);
      });
      console.log(`\n📝 Açıklama: ${description || '(boş)'}`);
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Allowlist yönetimi hatası:', error.message);
    process.exit(1);
  }
};

main();
