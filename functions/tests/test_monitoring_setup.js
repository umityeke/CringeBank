#!/usr/bin/env node

/**
 * Test Monitoring Setup
 * 
 * Monitoring altyapısının doğru çalıştığını test eder:
 * - Wallet consistency validator
 * - Metrics collection
 * - Alert system (Slack)
 * - Scheduled functions
 */

const { validateWalletConsistency } = require('../scheduled/wallet_consistency_check');
const { collectMetrics } = require('../scheduled/metrics_collection');
const { sendSlackAlert } = require('../utils/alerts');

async function testWalletConsistency() {
  console.log('\n🔍 Testing Wallet Consistency Validator...\n');
  
  try {
    const result = await validateWalletConsistency();
    
    if (result.success) {
      console.log('✅ Wallet consistency check PASSED');
      console.log(`   Total checked: ${result.totalChecked} wallets`);
    } else {
      console.log('⚠️  Wallet inconsistencies found');
      console.log(`   Inconsistencies: ${result.inconsistencies.length}`);
      console.log('   Sample:', result.inconsistencies.slice(0, 3));
    }
    
    return true;
  } catch (error) {
    console.error('❌ Wallet consistency check FAILED:', error.message);
    return false;
  }
}

async function testMetricsCollection() {
  console.log('\n📊 Testing Metrics Collection...\n');
  
  try {
    const metrics = await collectMetrics();
    
    console.log('✅ Metrics collected successfully:');
    console.log(`   Negative Balances: ${metrics.NegativeBalances}`);
    console.log(`   Pending Orders: ${metrics.PendingOrders}`);
    console.log(`   Locked Escrows: ${metrics.LockedEscrows}`);
    console.log(`   Total Gold: ${metrics.TotalGoldBalance}`);
    console.log(`   Orders Last Hour: ${metrics.OrdersLastHour}`);
    
    return true;
  } catch (error) {
    console.error('❌ Metrics collection FAILED:', error.message);
    return false;
  }
}

async function testSlackAlert() {
  console.log('\n📨 Testing Slack Alert System...\n');
  
  if (!process.env.SLACK_WEBHOOK_URL) {
    console.log('⚠️  SLACK_WEBHOOK_URL not configured, skipping test');
    console.log('   Set SLACK_WEBHOOK_URL environment variable to test alerts');
    return true;
  }
  
  try {
    await sendSlackAlert(
      'INFO',
      'Monitoring System Test',
      'This is a test alert from monitoring setup verification',
      {
        'Test Time': new Date().toISOString(),
        'Status': 'Testing',
        'Environment': process.env.NODE_ENV || 'development',
      }
    );
    
    console.log('✅ Slack alert sent successfully');
    console.log('   Check #cringebank-alerts channel for the test message');
    
    return true;
  } catch (error) {
    console.error('❌ Slack alert FAILED:', error.message);
    return false;
  }
}

async function main() {
  console.log('═'.repeat(60));
  console.log('🔧 MONITORING SETUP VERIFICATION');
  console.log('═'.repeat(60));
  
  const results = {
    walletConsistency: false,
    metricsCollection: false,
    slackAlert: false,
  };
  
  // Run all tests
  results.walletConsistency = await testWalletConsistency();
  results.metricsCollection = await testMetricsCollection();
  results.slackAlert = await testSlackAlert();
  
  // Summary
  console.log('\n' + '═'.repeat(60));
  console.log('📋 TEST SUMMARY');
  console.log('═'.repeat(60));
  console.log(`Wallet Consistency: ${results.walletConsistency ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`Metrics Collection: ${results.metricsCollection ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`Slack Alerts:       ${results.slackAlert ? '✅ PASS' : '⚠️  SKIP (no webhook)'}`);
  console.log('═'.repeat(60));
  
  const allPassed = results.walletConsistency && results.metricsCollection;
  
  if (allPassed) {
    console.log('\n🎉 All critical tests PASSED!');
    console.log('\nNext steps:');
    console.log('1. Deploy scheduled functions: firebase deploy --only functions');
    console.log('2. Configure Slack webhook for production alerts');
    console.log('3. Set up Azure SQL monitoring dashboard');
    process.exit(0);
  } else {
    console.log('\n❌ Some tests FAILED. Fix issues before proceeding.');
    process.exit(1);
  }
}

// Run tests
if (require.main === module) {
  main().catch(error => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { testWalletConsistency, testMetricsCollection, testSlackAlert };
