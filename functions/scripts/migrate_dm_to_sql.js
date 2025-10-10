/**
 * DM Migration Script
 * 
 * Migrates existing Firestore conversations and messages to SQL
 * 
 * Usage:
 *   node functions/scripts/migrate_dm_to_sql.js [--dry-run] [--conversation-id=xxx] [--limit=100]
 * 
 * Options:
 *   --dry-run: Preview migration without writing to SQL
 *   --conversation-id=xxx: Migrate only specific conversation
 *   --limit=N: Limit number of conversations to migrate (default: all)
 *   --batch-size=N: Messages per batch (default: 50)
 */

const admin = require('firebase-admin');
const sql = require('mssql');
const { getSqlConfig } = require('../utils/sql_config');

// Check if already initialized (if running as part of larger script)
if (!admin.apps.length) {
  admin.initializeApp();
}

const parseArgs = () => {
  const args = process.argv.slice(2);
  const options = {
    dryRun: false,
    conversationId: null,
    limit: null,
    batchSize: 50,
  };

  args.forEach(arg => {
    if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg.startsWith('--conversation-id=')) {
      options.conversationId = arg.split('=')[1];
    } else if (arg.startsWith('--limit=')) {
      options.limit = parseInt(arg.split('=')[1], 10);
    } else if (arg.startsWith('--batch-size=')) {
      options.batchSize = parseInt(arg.split('=')[1], 10);
    }
  });

  return options;
};

const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * Migrate a single conversation to SQL
 */
const migrateConversation = async (pool, conversationId, conversationData, stats, options) => {
  console.log(`\n📁 Processing conversation: ${conversationId}`);
  const participants = conversationId.split('_');
  
  if (participants.length !== 2) {
    console.log(`  ⚠️  Skipping invalid conversation ID format: ${conversationId}`);
    stats.errors++;
    return;
  }

  // Get messages from Firestore
  const messagesSnapshot = await admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .orderBy('createdAt', 'asc') // Oldest first
    .get();

  const totalMessages = messagesSnapshot.size;
  console.log(`  📨 Found ${totalMessages} messages`);

  if (totalMessages === 0) {
    stats.conversationsWithNoMessages++;
    return;
  }

  let migratedCount = 0;
  let errorCount = 0;

  // Process messages in batches
  const batches = [];
  let currentBatch = [];

  messagesSnapshot.docs.forEach(doc => {
    currentBatch.push({ id: doc.id, data: doc.data() });
    
    if (currentBatch.length >= options.batchSize) {
      batches.push(currentBatch);
      currentBatch = [];
    }
  });

  if (currentBatch.length > 0) {
    batches.push(currentBatch);
  }

  console.log(`  📦 Processing ${batches.length} batch(es) of messages...`);

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    console.log(`    Batch ${i + 1}/${batches.length} (${batch.length} messages)`);

    for (const msg of batch) {
      const msgData = msg.data;

      try {
        if (!options.dryRun) {
          // Insert message into SQL
          await pool.request()
            .input('MessagePublicId', sql.NVarChar(50), msg.id)
            .input('SenderAuthUid', sql.NVarChar(128), msgData.senderId || participants[0])
            .input('RecipientAuthUid', sql.NVarChar(128), msgData.recipientId || participants[1])
            .input('MessageText', sql.NVarChar(sql.MAX), msgData.text || msgData.messageText || null)
            .input('MessageType', sql.NVarChar(20), msgData.type || msgData.messageType || 'TEXT')
            .input('ImageUrl', sql.NVarChar(500), msgData.imageUrl || null)
            .input('VoiceUrl', sql.NVarChar(500), msgData.voiceUrl || null)
            .input('VoiceDurationSec', sql.Int, msgData.voiceDurationSec || null)
            .execute('sp_DM_SendMessage');
        }

        migratedCount++;
        stats.messagesMigrated++;
      } catch (error) {
        errorCount++;
        stats.errors++;
        console.log(`    ❌ Error migrating message ${msg.id}:`, error.message);
      }

      // Small delay to avoid overwhelming SQL
      if (!options.dryRun && migratedCount % 10 === 0) {
        await delay(100);
      }
    }
  }

  console.log(`  ✅ Migrated ${migratedCount}/${totalMessages} messages (${errorCount} errors)`);
  stats.conversationsMigrated++;
};

/**
 * Main migration function
 */
const migrateDMToSql = async (options) => {
  console.log('\n🚀 Starting DM Migration to SQL...');
  console.log('Options:', options);
  console.log('='.repeat(60));

  const stats = {
    conversationsScanned: 0,
    conversationsMigrated: 0,
    conversationsWithNoMessages: 0,
    messagesMigrated: 0,
    errors: 0,
    startTime: Date.now(),
  };

  let pool;

  try {
    // Connect to SQL
    if (!options.dryRun) {
      console.log('\n📡 Connecting to Azure SQL...');
      const sqlConfig = getSqlConfig();
      pool = await sql.connect(sqlConfig);
      console.log('✅ SQL connection established');
    } else {
      console.log('\n🔍 DRY RUN MODE - No SQL writes will be performed');
    }

    // Get conversations from Firestore
    let conversationsQuery = admin.firestore().collection('conversations');

    if (options.conversationId) {
      console.log(`\n📌 Migrating single conversation: ${options.conversationId}`);
      const conversationDoc = await conversationsQuery.doc(options.conversationId).get();
      
      if (!conversationDoc.exists) {
        throw new Error(`Conversation not found: ${options.conversationId}`);
      }

      await migrateConversation(pool, conversationDoc.id, conversationDoc.data(), stats, options);
    } else {
      // Migrate all conversations
      if (options.limit) {
        conversationsQuery = conversationsQuery.limit(options.limit);
      }

      const conversationsSnapshot = await conversationsQuery.get();
      console.log(`\n📊 Found ${conversationsSnapshot.size} conversation(s) to migrate`);

      for (const conversationDoc of conversationsSnapshot.docs) {
        stats.conversationsScanned++;
        await migrateConversation(pool, conversationDoc.id, conversationDoc.data(), stats, options);
        
        // Delay between conversations to avoid rate limits
        if (!options.dryRun) {
          await delay(200);
        }
      }
    }

    // Print summary
    const duration = ((Date.now() - stats.startTime) / 1000).toFixed(2);
    console.log('\n' + '='.repeat(60));
    console.log('📊 MIGRATION SUMMARY');
    console.log('='.repeat(60));
    console.log(`  Conversations scanned:     ${stats.conversationsScanned}`);
    console.log(`  Conversations migrated:    ${stats.conversationsMigrated}`);
    console.log(`  Conversations w/ no msgs:  ${stats.conversationsWithNoMessages}`);
    console.log(`  Messages migrated:         ${stats.messagesMigrated}`);
    console.log(`  Errors encountered:        ${stats.errors}`);
    console.log(`  Duration:                  ${duration}s`);
    console.log('='.repeat(60));

    if (options.dryRun) {
      console.log('\n🔍 DRY RUN COMPLETED - No data was written to SQL');
    } else {
      console.log('\n✅ MIGRATION COMPLETED SUCCESSFULLY');
    }

    process.exit(stats.errors > 0 ? 1 : 0);

  } catch (error) {
    console.error('\n❌ MIGRATION FAILED:', error);
    process.exit(1);
  } finally {
    if (pool) {
      await pool.close();
      console.log('\n📡 SQL connection closed');
    }
  }
};

// Run migration if executed directly
if (require.main === module) {
  const options = parseArgs();
  migrateDMToSql(options).catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { migrateDMToSql };
