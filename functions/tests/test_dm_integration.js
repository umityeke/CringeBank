/**
 * DM Integration Tests
 * 
 * Tests dual-write consistency between Firestore and SQL
 * 
 * Prerequisites:
 *   - Firebase Admin SDK initialized
 *   - SQL connection configured
 *   - Test users created in Auth
 * 
 * Usage:
 *   npm test -- test_dm_integration.js
 */

const admin = require('firebase-admin');
const sql = require('mssql');
const assert = require('assert');
const { getSqlConfig } = require('../utils/sql_config');

// Check if already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const TEST_TIMEOUT = 30000; // 30 seconds

describe('DM Dual-Write Integration Tests', function() {
  this.timeout(TEST_TIMEOUT);

  let pool;
  let testUserA;
  let testUserB;

  before(async function() {
    console.log('🔧 Setting up test environment...');
    
    // Connect to SQL
    const sqlConfig = getSqlConfig();
    pool = await sql.connect(sqlConfig);
    console.log('✅ SQL connected');

    // Create test users (or use existing)
    testUserA = {
      uid: 'test_user_a_' + Date.now(),
      displayName: 'Test User A',
      email: 'test_a@example.com',
    };

    testUserB = {
      uid: 'test_user_b_' + Date.now(),
      displayName: 'Test User B',
      email: 'test_b@example.com',
    };

    console.log('✅ Test users prepared');
  });

  after(async function() {
    console.log('🧹 Cleaning up...');
    
    if (pool) {
      await pool.close();
      console.log('✅ SQL connection closed');
    }

    // Clean up test data (optional)
    // await cleanupTestData();
  });

  describe('sendMessage Dual-Write', function() {
    it('should write message to both Firestore and SQL', async function() {
      const conversationId = [testUserA.uid, testUserB.uid].sort().join('_');
      const messageText = 'Test message at ' + new Date().toISOString();

      // Send message via Cloud Function
      const dmSendMessage = require('../dm/send_message');
      const result = await dmSendMessage.sendMessage(
        {
          recipientUid: testUserB.uid,
          text: messageText,
        },
        {
          auth: { uid: testUserA.uid },
        }
      );

      assert.ok(result.data.success, 'Message send should succeed');
      assert.ok(result.data.messageId, 'Should return messageId');

      const messageId = result.data.messageId;

      // Wait for writes to complete
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Verify Firestore write
      const firestoreMessage = await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .get();

      assert.ok(firestoreMessage.exists, 'Message should exist in Firestore');
      const firestoreData = firestoreMessage.data();
      assert.strictEqual(firestoreData.text, messageText, 'Firestore text should match');
      assert.strictEqual(firestoreData.senderId, testUserA.uid, 'Firestore senderId should match');

      // Verify SQL write
      const sqlResult = await pool.request()
        .input('MessagePublicId', sql.NVarChar(50), messageId)
        .query('SELECT * FROM Messages WHERE MessagePublicId = @MessagePublicId');

      assert.strictEqual(sqlResult.recordset.length, 1, 'Message should exist in SQL');
      const sqlData = sqlResult.recordset[0];
      assert.strictEqual(sqlData.MessageText, messageText, 'SQL text should match');
      assert.strictEqual(sqlData.SenderAuthUid, testUserA.uid, 'SQL senderId should match');
      assert.strictEqual(sqlData.ConversationId, conversationId, 'SQL conversationId should match');

      console.log('✅ Dual-write verified: Message exists in both Firestore and SQL');
    });

    it('should update conversation metadata in both sources', async function() {
      const conversationId = [testUserA.uid, testUserB.uid].sort().join('_');

      // Verify Firestore conversation
      const firestoreConv = await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .get();

      assert.ok(firestoreConv.exists, 'Conversation should exist in Firestore');

      // Verify SQL conversation
      const sqlConv = await pool.request()
        .input('ConversationId', sql.NVarChar(100), conversationId)
        .query('SELECT * FROM Conversations WHERE ConversationId = @ConversationId');

      assert.strictEqual(sqlConv.recordset.length, 1, 'Conversation should exist in SQL');
      const sqlConvData = sqlConv.recordset[0];
      assert.ok(sqlConvData.LastMessageText, 'Should have last message text');
      assert.ok(sqlConvData.LastMessageAt, 'Should have last message timestamp');

      console.log('✅ Conversation metadata verified in both sources');
    });
  });

  describe('getMessages SQL Primary with Fallback', function() {
    it('should fetch messages from SQL', async function() {
      const conversationId = [testUserA.uid, testUserB.uid].sort().join('_');

      const dmGetMessages = require('../dm/get_messages');
      const result = await dmGetMessages.getMessages(
        {
          conversationId: conversationId,
          limit: 50,
        },
        {
          auth: { uid: testUserA.uid },
        }
      );

      assert.ok(result.data.success, 'getMessages should succeed');
      assert.ok(Array.isArray(result.data.messages), 'Should return messages array');
      assert.strictEqual(result.data.source, 'sql', 'Should fetch from SQL');
      assert.ok(result.data.messages.length > 0, 'Should have at least one message');

      console.log(`✅ Fetched ${result.data.messages.length} messages from SQL`);
    });

    it('should fallback to Firestore on SQL error', async function() {
      // Temporarily disable SQL (simulate error by using invalid conversationId format)
      const dmGetMessages = require('../dm/get_messages');
      
      // This should trigger SQL error and fallback to Firestore
      const result = await dmGetMessages.getMessages(
        {
          conversationId: 'invalid_format_conversation',
          limit: 50,
        },
        {
          auth: { uid: testUserA.uid },
        }
      );

      // Should still succeed via Firestore fallback
      assert.ok(result.data.success, 'Should succeed via fallback');
      assert.strictEqual(result.data.source, 'firestore', 'Should fallback to Firestore');

      console.log('✅ Firestore fallback verified');
    });
  });

  describe('markAsRead Dual-Write', function() {
    it('should mark messages as read in both sources', async function() {
      const conversationId = [testUserA.uid, testUserB.uid].sort().join('_');

      // Send a message from A to B
      const dmSendMessage = require('../dm/send_message');
      await dmSendMessage.sendMessage(
        {
          recipientUid: testUserB.uid,
          text: 'Unread message test',
        },
        {
          auth: { uid: testUserA.uid },
        }
      );

      // Wait for write
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Mark as read (as user B)
      const dmMarkAsRead = require('../dm/mark_as_read');
      const result = await dmMarkAsRead.markAsRead(
        {
          conversationId: conversationId,
        },
        {
          auth: { uid: testUserB.uid },
        }
      );

      assert.ok(result.data.success, 'markAsRead should succeed');

      // Wait for dual-write
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Verify Firestore (check unread count)
      const firestoreConv = await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .get();

      const convData = firestoreConv.data();
      const unreadCountKey = `unreadCount_${testUserB.uid}`;
      assert.strictEqual(convData[unreadCountKey], 0, 'Firestore unread count should be 0');

      // Verify SQL (check unread count)
      const sqlConv = await pool.request()
        .input('ConversationId', sql.NVarChar(100), conversationId)
        .query('SELECT * FROM Conversations WHERE ConversationId = @ConversationId');

      const sqlConvData = sqlConv.recordset[0];
      const participant1 = sqlConvData.Participant1AuthUid;
      const unreadCount = participant1 === testUserB.uid 
        ? sqlConvData.UnreadCountP1 
        : sqlConvData.UnreadCountP2;
      
      assert.strictEqual(unreadCount, 0, 'SQL unread count should be 0');

      console.log('✅ Mark as read verified in both sources');
    });
  });

  describe('getConversations SQL Primary with Fallback', function() {
    it('should fetch conversations from SQL', async function() {
      const dmGetConversations = require('../dm/get_conversations');
      const result = await dmGetConversations.getConversations(
        {
          limit: 50,
        },
        {
          auth: { uid: testUserA.uid },
        }
      );

      assert.ok(result.data.success, 'getConversations should succeed');
      assert.ok(Array.isArray(result.data.conversations), 'Should return conversations array');
      assert.strictEqual(result.data.source, 'sql', 'Should fetch from SQL');
      assert.ok(result.data.conversations.length > 0, 'Should have at least one conversation');

      const conv = result.data.conversations[0];
      assert.ok(conv.conversationId, 'Should have conversationId');
      assert.ok(conv.otherParticipantUid, 'Should have otherParticipantUid');

      console.log(`✅ Fetched ${result.data.conversations.length} conversations from SQL`);
    });
  });

  describe('RBAC Verification', function() {
    it('should prevent unauthorized access to messages', async function() {
      const conversationId = [testUserA.uid, testUserB.uid].sort().join('_');
      const unauthorizedUser = { uid: 'unauthorized_user_' + Date.now() };

      const dmGetMessages = require('../dm/get_messages');
      
      try {
        await dmGetMessages.getMessages(
          {
            conversationId: conversationId,
            limit: 50,
          },
          {
            auth: { uid: unauthorizedUser.uid },
          }
        );
        
        assert.fail('Should throw error for unauthorized user');
      } catch (error) {
        assert.ok(error.message.includes('Unauthorized') || error.message.includes('Not a conversation participant'));
        console.log('✅ RBAC verification passed: Unauthorized access blocked');
      }
    });
  });

  describe('Pagination Tests', function() {
    it('should paginate messages correctly', async function() {
      const conversationId = [testUserA.uid, testUserB.uid].sort().join('_');

      // Fetch first page
      const dmGetMessages = require('../dm/get_messages');
      const page1 = await dmGetMessages.getMessages(
        {
          conversationId: conversationId,
          limit: 2,
        },
        {
          auth: { uid: testUserA.uid },
        }
      );

      assert.ok(page1.data.messages.length <= 2, 'Should respect limit');

      if (page1.data.messages.length > 0) {
        // Fetch second page
        const lastMessageId = page1.data.messages[page1.data.messages.length - 1].id;
        const page2 = await dmGetMessages.getMessages(
          {
            conversationId: conversationId,
            limit: 2,
            beforeMessageId: lastMessageId,
          },
          {
            auth: { uid: testUserA.uid },
          }
        );

        assert.ok(page2.data.success, 'Second page should succeed');
        console.log('✅ Pagination verified');
      }
    });
  });
});

console.log('✅ All DM Integration Tests loaded');
