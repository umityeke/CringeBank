/**
 * Timeline Migration Script
 * 
 * Migrates existing Firestore timeline events to SQL
 * 
 * Usage:
 *   node functions/scripts/migrate_timeline_to_sql.js [--dry-run] [--limit=100]
 * 
 * Options:
 *   --dry-run: Preview migration without writing to SQL
 *   --limit=N: Limit number of events to migrate (default: all)
 *   --batch-size=N: Events per batch (default: 100)
 */

const admin = require('firebase-admin');
const sql = require('mssql');
const { getSqlConfig } = require('../utils/sql_config');

// Check if already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const parseArgs = () => {
  const args = process.argv.slice(2);
  const options = {
    dryRun: false,
    limit: null,
    batchSize: 100,
  };

  args.forEach(arg => {
    if (arg === '--dry-run') {
      options.dryRun = true;
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
 * Get followers for a user (for fan-out)
 */
const getFollowers = async (actorUid) => {
  try {
    const followersSnapshot = await admin.firestore()
      .collection('follows')
      .where('followingUid', '==', actorUid)
      .get();

    return followersSnapshot.docs.map(doc => doc.data().followerUid);
  } catch (error) {
    console.log(`  ⚠️  Could not fetch followers for ${actorUid}: ${error.message}`);
    return [];
  }
};

/**
 * Migrate a single timeline event to SQL
 */
const migrateEvent = async (pool, eventDoc, stats, options) => {
  const eventData = eventDoc.data();
  const eventId = eventDoc.id;

  console.log(`\n📌 Processing event: ${eventId}`);

  try {
    const {
      eventPublicId = eventId,
      actorAuthUid,
      eventType,
      entityType,
      entityId,
      metadata = {},
      createdAt,
    } = eventData;

    // Validation
    if (!actorAuthUid || !eventType || !entityType || !entityId) {
      console.log(`  ⚠️  Skipping invalid event (missing required fields)`);
      stats.skipped++;
      return;
    }

    if (!options.dryRun) {
      // Get followers for fan-out
      const followers = await getFollowers(actorAuthUid);
      const followerUids = followers.join(',');

      // Insert event into SQL
      await pool.request()
        .input('EventPublicId', sql.NVarChar(50), eventPublicId)
        .input('ActorAuthUid', sql.NVarChar(128), actorAuthUid)
        .input('EventType', sql.NVarChar(50), eventType)
        .input('EntityType', sql.NVarChar(50), entityType)
        .input('EntityId', sql.NVarChar(128), entityId)
        .input('MetadataJson', sql.NVarChar(sql.MAX), JSON.stringify(metadata))
        .input('FollowerAuthUids', sql.NVarChar(sql.MAX), followerUids || null)
        .execute('sp_Timeline_CreateEvent');

      console.log(`  ✅ Migrated event (${followers.length} followers)`);
    } else {
      console.log(`  🔍 [DRY-RUN] Would migrate event`);
    }

    stats.eventsMigrated++;
  } catch (error) {
    stats.errors++;
    console.log(`  ❌ Error migrating event ${eventId}:`, error.message);
  }
};

/**
 * Main migration function
 */
const migrateTimelineToSql = async (options) => {
  console.log('\n🚀 Starting Timeline Migration to SQL...');
  console.log('Options:', options);
  console.log('='.repeat(60));

  const stats = {
    eventsScanned: 0,
    eventsMigrated: 0,
    skipped: 0,
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

    // Get timeline events from Firestore
    let eventsQuery = admin.firestore()
      .collection('timeline_events')
      .orderBy('createdAt', 'desc');

    if (options.limit) {
      eventsQuery = eventsQuery.limit(options.limit);
    }

    const eventsSnapshot = await eventsQuery.get();
    console.log(`\n📊 Found ${eventsSnapshot.size} timeline event(s) to migrate`);

    // Process events in batches
    const batches = [];
    let currentBatch = [];

    eventsSnapshot.docs.forEach(doc => {
      currentBatch.push(doc);
      if (currentBatch.length >= options.batchSize) {
        batches.push(currentBatch);
        currentBatch = [];
      }
    });

    if (currentBatch.length > 0) {
      batches.push(currentBatch);
    }

    console.log(`\n📦 Processing ${batches.length} batch(es)...`);

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      console.log(`\n  Batch ${i + 1}/${batches.length} (${batch.length} events)`);

      for (const eventDoc of batch) {
        stats.eventsScanned++;
        await migrateEvent(pool, eventDoc, stats, options);
        
        // Small delay to avoid rate limits
        if (!options.dryRun && stats.eventsScanned % 10 === 0) {
          await delay(100);
        }
      }
    }

    // Print summary
    const duration = ((Date.now() - stats.startTime) / 1000).toFixed(2);
    console.log('\n' + '='.repeat(60));
    console.log('📊 MIGRATION SUMMARY');
    console.log('='.repeat(60));
    console.log(`  Events scanned:      ${stats.eventsScanned}`);
    console.log(`  Events migrated:     ${stats.eventsMigrated}`);
    console.log(`  Events skipped:      ${stats.skipped}`);
    console.log(`  Errors encountered:  ${stats.errors}`);
    console.log(`  Duration:            ${duration}s`);
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
  migrateTimelineToSql(options).catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { migrateTimelineToSql };
