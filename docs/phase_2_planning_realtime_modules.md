# Faz 2: Real-time Modüller SQL Migration Planı

**Tarih:** 9 Ekim 2025  
**Kapsam:** DM, Timeline, Notifications modüllerinin SQL'e taşınması  
**Strateji:** Çift yazma (dual-write) ile kademeli geçiş

---

## 🎯 Overview

**Hedef Modüller:**
1. **Direct Messaging (DM)** - Kullanıcılar arası mesajlaşma
2. **Timeline/Feed** - Takip edilen kullanıcıların aktiviteleri
3. **Notifications** - Uygulama içi bildirimler

**Kritik Zorluk:**  
Bu modüller **real-time** özellik gerektirir. Firestore'un real-time listeners'ını koruyarak SQL'e taşıma yapmak gerekiyor.

**Çözüm Stratejisi:**
- **Faz 2.1:** Çift yazma (Firestore + SQL) - Yazma işlemleri her iki yere de gider
- **Faz 2.2:** Okuma SQL'den, real-time Firestore'dan (hybrid)
- **Faz 2.3:** SQL real-time (SignalR/WebSocket) + Firestore deprecation

---

## 📋 Faz 2.1: Direct Messaging (DM) SQL Aynası

### 1.1 SQL Schema Design

**Messages Table:**

```sql
CREATE TABLE Messages (
    MessageId BIGINT IDENTITY(1,1) PRIMARY KEY,
    MessagePublicId NVARCHAR(50) NOT NULL UNIQUE,
    ConversationId NVARCHAR(100) NOT NULL,
    SenderAuthUid NVARCHAR(128) NOT NULL,
    RecipientAuthUid NVARCHAR(128) NOT NULL,
    MessageText NVARCHAR(MAX) NULL,
    MessageType NVARCHAR(20) NOT NULL DEFAULT 'TEXT', -- TEXT, IMAGE, VOICE, etc.
    ImageUrl NVARCHAR(500) NULL,
    VoiceUrl NVARCHAR(500) NULL,
    IsRead BIT NOT NULL DEFAULT 0,
    IsDeleted BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    ReadAt DATETIME NULL,
    DeletedAt DATETIME NULL,
    
    INDEX IX_Messages_ConversationId (ConversationId),
    INDEX IX_Messages_SenderAuthUid (SenderAuthUid),
    INDEX IX_Messages_RecipientAuthUid (RecipientAuthUid),
    INDEX IX_Messages_CreatedAt (CreatedAt DESC)
);
```

**Conversations Table (Optional - Denormalization for performance):**

```sql
CREATE TABLE Conversations (
    ConversationId NVARCHAR(100) PRIMARY KEY,
    Participant1AuthUid NVARCHAR(128) NOT NULL,
    Participant2AuthUid NVARCHAR(128) NOT NULL,
    LastMessageText NVARCHAR(500) NULL,
    LastMessageAt DATETIME NULL,
    UnreadCountP1 INT NOT NULL DEFAULT 0, -- Participant 1'in okunmamış mesaj sayısı
    UnreadCountP2 INT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    
    INDEX IX_Conversations_Participant1 (Participant1AuthUid, UpdatedAt DESC),
    INDEX IX_Conversations_Participant2 (Participant2AuthUid, UpdatedAt DESC)
);
```

**Rationale:**
- `MessagePublicId`: Client-facing ID (Firestore doc ID ile sync)
- `ConversationId`: Format: `{uid1}_{uid2}` (sorted alphabetically)
- `IsDeleted`: Soft delete (Firestore'da da tutuyoruz)
- Denormalized `Conversations` table: Conversation list query hızlandırması

---

### 1.2 Stored Procedures

**sp_DM_SendMessage:**

```sql
CREATE OR ALTER PROCEDURE sp_DM_SendMessage
    @MessagePublicId NVARCHAR(50),
    @SenderAuthUid NVARCHAR(128),
    @RecipientAuthUid NVARCHAR(128),
    @MessageText NVARCHAR(MAX) = NULL,
    @MessageType NVARCHAR(20) = 'TEXT',
    @ImageUrl NVARCHAR(500) = NULL,
    @VoiceUrl NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ConversationId NVARCHAR(100);
    
    -- Generate conversation ID (sorted)
    IF @SenderAuthUid < @RecipientAuthUid
        SET @ConversationId = @SenderAuthUid + '_' + @RecipientAuthUid;
    ELSE
        SET @ConversationId = @RecipientAuthUid + '_' + @SenderAuthUid;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Insert message
        INSERT INTO Messages (
            MessagePublicId, ConversationId, SenderAuthUid, RecipientAuthUid,
            MessageText, MessageType, ImageUrl, VoiceUrl
        )
        VALUES (
            @MessagePublicId, @ConversationId, @SenderAuthUid, @RecipientAuthUid,
            @MessageText, @MessageType, @ImageUrl, @VoiceUrl
        );
        
        -- Update or create conversation
        MERGE Conversations AS target
        USING (SELECT @ConversationId AS ConversationId) AS source
        ON target.ConversationId = source.ConversationId
        WHEN MATCHED THEN
            UPDATE SET
                LastMessageText = @MessageText,
                LastMessageAt = GETUTCDATE(),
                UnreadCountP1 = CASE 
                    WHEN Participant1AuthUid = @RecipientAuthUid THEN UnreadCountP1 + 1 
                    ELSE UnreadCountP1 
                END,
                UnreadCountP2 = CASE 
                    WHEN Participant2AuthUid = @RecipientAuthUid THEN UnreadCountP2 + 1 
                    ELSE UnreadCountP2 
                END,
                UpdatedAt = GETUTCDATE()
        WHEN NOT MATCHED THEN
            INSERT (ConversationId, Participant1AuthUid, Participant2AuthUid, LastMessageText, LastMessageAt)
            VALUES (@ConversationId, @SenderAuthUid, @RecipientAuthUid, @MessageText, GETUTCDATE());
        
        COMMIT TRANSACTION;
        
        SELECT @MessagePublicId AS MessagePublicId, @ConversationId AS ConversationId;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO
```

**sp_DM_GetMessages:**

```sql
CREATE OR ALTER PROCEDURE sp_DM_GetMessages
    @ConversationId NVARCHAR(100),
    @RequestorAuthUid NVARCHAR(128),
    @Limit INT = 50,
    @BeforeMessageId BIGINT = NULL -- Pagination
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Verify requestor is participant
    DECLARE @IsParticipant BIT = 0;
    
    SELECT @IsParticipant = 1
    FROM Conversations
    WHERE ConversationId = @ConversationId
      AND (Participant1AuthUid = @RequestorAuthUid OR Participant2AuthUid = @RequestorAuthUid);
    
    IF @IsParticipant = 0
    BEGIN
        RAISERROR('Unauthorized: Not a conversation participant', 16, 1);
        RETURN;
    END
    
    -- Get messages
    SELECT TOP (@Limit)
        MessageId,
        MessagePublicId,
        SenderAuthUid,
        RecipientAuthUid,
        MessageText,
        MessageType,
        ImageUrl,
        VoiceUrl,
        IsRead,
        CreatedAt,
        ReadAt
    FROM Messages
    WHERE ConversationId = @ConversationId
      AND IsDeleted = 0
      AND (@BeforeMessageId IS NULL OR MessageId < @BeforeMessageId)
    ORDER BY MessageId DESC;
END
GO
```

**sp_DM_MarkAsRead:**

```sql
CREATE OR ALTER PROCEDURE sp_DM_MarkAsRead
    @ConversationId NVARCHAR(100),
    @ReaderAuthUid NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Mark all unread messages as read
        UPDATE Messages
        SET IsRead = 1, ReadAt = GETUTCDATE()
        WHERE ConversationId = @ConversationId
          AND RecipientAuthUid = @ReaderAuthUid
          AND IsRead = 0;
        
        -- Reset unread count in conversation
        UPDATE Conversations
        SET 
            UnreadCountP1 = CASE WHEN Participant1AuthUid = @ReaderAuthUid THEN 0 ELSE UnreadCountP1 END,
            UnreadCountP2 = CASE WHEN Participant2AuthUid = @ReaderAuthUid THEN 0 ELSE UnreadCountP2 END,
            UpdatedAt = GETUTCDATE()
        WHERE ConversationId = @ConversationId;
        
        COMMIT TRANSACTION;
        
        SELECT @@ROWCOUNT AS MessagesMarkedAsRead;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO
```

---

### 1.3 Dual-Write Strategy

**Cloud Function: sendMessage (Modified)**

```javascript
// functions/dm/send_message.js
const admin = require('firebase-admin');
const sql = require('mssql');

exports.sendMessage = functions.https.onCall(async (data, context) => {
  const { recipientUid, messageText, messageType = 'TEXT' } = data;
  const senderUid = context.auth.uid;
  
  const messageId = generateMessageId();
  const conversationId = [senderUid, recipientUid].sort().join('_');
  
  // 🔥 DUAL WRITE: Firestore + SQL
  
  // 1. Write to Firestore (for real-time listeners)
  await admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .doc(messageId)
    .set({
      senderId: senderUid,
      recipientId: recipientUid,
      text: messageText,
      type: messageType,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  
  // 2. Write to SQL (for historical queries & analytics)
  const pool = await getSqlPool();
  await pool.request()
    .input('MessagePublicId', sql.NVarChar, messageId)
    .input('SenderAuthUid', sql.NVarChar, senderUid)
    .input('RecipientAuthUid', sql.NVarChar, recipientUid)
    .input('MessageText', sql.NVarChar, messageText)
    .input('MessageType', sql.NVarChar, messageType)
    .execute('sp_DM_SendMessage');
  
  // 3. Update conversation metadata (Firestore)
  await admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .set({
      participants: [senderUid, recipientUid],
      lastMessage: messageText,
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      [`unreadCount_${recipientUid}`]: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
  
  return { messageId, conversationId };
});
```

**Key Points:**
- ✅ **Write to both** Firestore and SQL atomically (use try/catch for rollback)
- ✅ Firestore provides **real-time updates** (existing Flutter listeners work)
- ✅ SQL provides **historical queries**, **analytics**, **search**
- ⚠️ **Eventual consistency** risk (if one write fails)

**Error Handling:**

```javascript
try {
  // Write to Firestore
  await firestoreWrite();
  
  try {
    // Write to SQL
    await sqlWrite();
  } catch (sqlError) {
    // SQL write failed - log and alert, but don't fail the request
    // Firestore is source of truth for real-time
    console.error('SQL write failed (non-critical):', sqlError);
    await sendAlert('SQL DM Write Failed', sqlError.message);
  }
} catch (firestoreError) {
  // Firestore write failed - critical error
  throw new functions.https.HttpsError('internal', 'Message send failed');
}
```

---

### 1.4 Migration Script

**Migrate existing DM conversations to SQL:**

```javascript
// functions/scripts/migrate_dm_to_sql.js
async function migrateDMConversations() {
  const db = admin.firestore();
  const pool = await sql.connect(sqlConfig);
  
  const conversationsSnapshot = await db.collection('conversations').get();
  
  for (const convDoc of conversationsSnapshot.docs) {
    const conversationId = convDoc.id;
    
    // Get all messages in conversation
    const messagesSnapshot = await convDoc.ref.collection('messages').get();
    
    for (const msgDoc of messagesSnapshot.docs) {
      const msg = msgDoc.data();
      
      await pool.request()
        .input('MessagePublicId', sql.NVarChar, msgDoc.id)
        .input('SenderAuthUid', sql.NVarChar, msg.senderId)
        .input('RecipientAuthUid', sql.NVarChar, msg.recipientId)
        .input('MessageText', sql.NVarChar, msg.text)
        .input('MessageType', sql.NVarChar, msg.type || 'TEXT')
        .execute('sp_DM_SendMessage');
      
      console.log(`Migrated message: ${msgDoc.id}`);
    }
  }
  
  console.log('DM migration complete');
}
```

---

## 📋 Faz 2.2: Timeline/Feed SQL Integration

### 2.1 SQL Schema

**TimelineEvents Table:**

```sql
CREATE TABLE TimelineEvents (
    EventId BIGINT IDENTITY(1,1) PRIMARY KEY,
    EventPublicId NVARCHAR(50) NOT NULL UNIQUE,
    ActorAuthUid NVARCHAR(128) NOT NULL, -- Eylemi yapan kullanıcı
    EventType NVARCHAR(50) NOT NULL, -- POST_CREATED, ENTRY_SHARED, USER_FOLLOWED, etc.
    EntityType NVARCHAR(50) NOT NULL, -- ENTRY, POST, USER
    EntityId NVARCHAR(100) NOT NULL, -- Entry ID, Post ID, User ID
    MetadataJson NVARCHAR(MAX) NULL, -- Ek bilgi (JSON)
    CreatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    
    INDEX IX_TimelineEvents_ActorAuthUid (ActorAuthUid, CreatedAt DESC),
    INDEX IX_TimelineEvents_EventType (EventType, CreatedAt DESC),
    INDEX IX_TimelineEvents_CreatedAt (CreatedAt DESC)
);
```

**UserFollowTimeline (Denormalized - Fan-out on write):**

```sql
CREATE TABLE UserFollowTimeline (
    TimelineId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ViewerAuthUid NVARCHAR(128) NOT NULL, -- Feed'i gören kullanıcı
    EventId BIGINT NOT NULL, -- TimelineEvents FK
    IsRead BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    
    FOREIGN KEY (EventId) REFERENCES TimelineEvents(EventId),
    INDEX IX_UserFollowTimeline_ViewerAuthUid (ViewerAuthUid, CreatedAt DESC)
);
```

**Rationale:**
- **TimelineEvents**: Tüm aktivitelerin merkezi logu
- **UserFollowTimeline**: Her kullanıcının kendi feed'i (fan-out on write)
- **Fan-out on write**: Bir kullanıcı post attığında, tüm follower'larının timeline'ına yazılır (okuma hızlı, yazma yavaş)

---

### 2.2 Stored Procedures

**sp_Timeline_CreateEvent:**

```sql
CREATE OR ALTER PROCEDURE sp_Timeline_CreateEvent
    @EventPublicId NVARCHAR(50),
    @ActorAuthUid NVARCHAR(128),
    @EventType NVARCHAR(50),
    @EntityType NVARCHAR(50),
    @EntityId NVARCHAR(100),
    @MetadataJson NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @EventId BIGINT;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Insert event
        INSERT INTO TimelineEvents (EventPublicId, ActorAuthUid, EventType, EntityType, EntityId, MetadataJson)
        VALUES (@EventPublicId, @ActorAuthUid, @EventType, @EntityType, @EntityId, @MetadataJson);
        
        SET @EventId = SCOPE_IDENTITY();
        
        -- Fan-out to followers' timelines
        INSERT INTO UserFollowTimeline (ViewerAuthUid, EventId, CreatedAt)
        SELECT 
            FollowerAuthUid,
            @EventId,
            GETUTCDATE()
        FROM Follows
        WHERE FollowedAuthUid = @ActorAuthUid
          AND IsActive = 1;
        
        COMMIT TRANSACTION;
        
        SELECT @EventId AS EventId, @@ROWCOUNT AS FannedOutToCount;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO
```

**sp_Timeline_GetUserFeed:**

```sql
CREATE OR ALTER PROCEDURE sp_Timeline_GetUserFeed
    @ViewerAuthUid NVARCHAR(128),
    @Limit INT = 20,
    @BeforeEventId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@Limit)
        e.EventId,
        e.EventPublicId,
        e.ActorAuthUid,
        e.EventType,
        e.EntityType,
        e.EntityId,
        e.MetadataJson,
        e.CreatedAt,
        t.IsRead
    FROM UserFollowTimeline t
    INNER JOIN TimelineEvents e ON t.EventId = e.EventId
    WHERE t.ViewerAuthUid = @ViewerAuthUid
      AND (@BeforeEventId IS NULL OR t.EventId < @BeforeEventId)
    ORDER BY t.CreatedAt DESC;
END
GO
```

---

### 2.3 Dual-Write for Timeline

**When user creates a post:**

```javascript
// functions/timeline/on_post_created.js
exports.onPostCreated = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const post = snap.data();
    const authorUid = post.authorUid;
    const postId = context.params.postId;
    
    // 1. Write to Firestore timeline (existing)
    await admin.firestore()
      .collection('timeline_events')
      .add({
        actorUid: authorUid,
        eventType: 'POST_CREATED',
        entityType: 'POST',
        entityId: postId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    // 2. Write to SQL timeline (new)
    const pool = await getSqlPool();
    await pool.request()
      .input('EventPublicId', sql.NVarChar, generateEventId())
      .input('ActorAuthUid', sql.NVarChar, authorUid)
      .input('EventType', sql.NVarChar, 'POST_CREATED')
      .input('EntityType', sql.NVarChar, 'POST')
      .input('EntityId', sql.NVarChar, postId)
      .execute('sp_Timeline_CreateEvent');
  });
```

---

## 📋 Faz 2.3: Notifications SQL Integration

### 3.1 SQL Schema

**Notifications Table:**

```sql
CREATE TABLE Notifications (
    NotificationId BIGINT IDENTITY(1,1) PRIMARY KEY,
    NotificationPublicId NVARCHAR(50) NOT NULL UNIQUE,
    RecipientAuthUid NVARCHAR(128) NOT NULL,
    SenderAuthUid NVARCHAR(128) NULL, -- NULL for system notifications
    NotificationType NVARCHAR(50) NOT NULL, -- MESSAGE, FOLLOW, LIKE, COMMENT, SYSTEM
    Title NVARCHAR(200) NOT NULL,
    Body NVARCHAR(500) NULL,
    ActionUrl NVARCHAR(500) NULL, -- Deep link
    ImageUrl NVARCHAR(500) NULL,
    IsRead BIT NOT NULL DEFAULT 0,
    IsPushed BIT NOT NULL DEFAULT 0, -- FCM push notification sent
    CreatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    ReadAt DATETIME NULL,
    
    INDEX IX_Notifications_RecipientAuthUid (RecipientAuthUid, CreatedAt DESC),
    INDEX IX_Notifications_IsRead (RecipientAuthUid, IsRead, CreatedAt DESC)
);
```

### 3.2 Stored Procedures

**sp_Notifications_Create:**

```sql
CREATE OR ALTER PROCEDURE sp_Notifications_Create
    @NotificationPublicId NVARCHAR(50),
    @RecipientAuthUid NVARCHAR(128),
    @SenderAuthUid NVARCHAR(128) = NULL,
    @NotificationType NVARCHAR(50),
    @Title NVARCHAR(200),
    @Body NVARCHAR(500) = NULL,
    @ActionUrl NVARCHAR(500) = NULL,
    @ImageUrl NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Notifications (
        NotificationPublicId, RecipientAuthUid, SenderAuthUid,
        NotificationType, Title, Body, ActionUrl, ImageUrl
    )
    VALUES (
        @NotificationPublicId, @RecipientAuthUid, @SenderAuthUid,
        @NotificationType, @Title, @Body, @ActionUrl, @ImageUrl
    );
    
    SELECT @NotificationPublicId AS NotificationPublicId;
END
GO
```

**sp_Notifications_GetUnread:**

```sql
CREATE OR ALTER PROCEDURE sp_Notifications_GetUnread
    @RecipientAuthUid NVARCHAR(128),
    @Limit INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@Limit)
        NotificationId,
        NotificationPublicId,
        SenderAuthUid,
        NotificationType,
        Title,
        Body,
        ActionUrl,
        ImageUrl,
        CreatedAt
    FROM Notifications
    WHERE RecipientAuthUid = @RecipientAuthUid
      AND IsRead = 0
    ORDER BY CreatedAt DESC;
END
GO
```

---

## 🔄 Event Queue Architecture (Future - Faz 2.4)

**Problem:**  
Firestore real-time listeners'ı SQL ile replace etmek zor. WebSocket/SignalR gerekli.

**Solution Options:**

### Option 1: Google Cloud Pub/Sub

```
User Action → Cloud Function → Pub/Sub Topic → Subscriber → SQL Write
                                             ↘ Subscriber → FCM Push
                                             ↘ Subscriber → Firestore (temp)
```

**Pros:**
- Scalable, reliable message queue
- Multiple subscribers (SQL, FCM, analytics)
- Retry logic built-in

**Cons:**
- Additional cost
- Complexity

---

### Option 2: Azure Service Bus

```
User Action → Cloud Function → Service Bus Queue → Azure Function → SQL Write
                                                 ↘ Logic App → Email/Slack
```

**Pros:**
- Native SQL integration (Azure ecosystem)
- Dead-letter queue for failed messages

**Cons:**
- Vendor lock-in (Azure)
- Firebase + Azure hybrid complexity

---

### Option 3: SQL-based Event Log + Polling (Simple)

```sql
CREATE TABLE EventQueue (
    EventId BIGINT IDENTITY(1,1) PRIMARY KEY,
    EventType NVARCHAR(50) NOT NULL,
    Payload NVARCHAR(MAX) NOT NULL, -- JSON
    ProcessedAt DATETIME NULL,
    CreatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    
    INDEX IX_EventQueue_Unprocessed (ProcessedAt, CreatedAt)
);
```

**Flutter polling:**

```dart
Timer.periodic(Duration(seconds: 5), (timer) async {
  final events = await fetchUnprocessedEvents();
  for (var event in events) {
    _handleEvent(event);
  }
});
```

**Pros:**
- Simple, no external dependencies
- SQL transaction consistency

**Cons:**
- Not true real-time (polling delay)
- Client battery drain

---

## 📊 Comparison: Firestore vs SQL for Real-time

| Feature | Firestore | SQL + WebSocket |
|---------|-----------|-----------------|
| Real-time Updates | ✅ Native | ⚠️ Requires SignalR/WebSocket |
| Query Performance | ⚠️ Limited indexing | ✅ Flexible indexes |
| Complex Queries | ❌ Weak (no JOINs) | ✅ Full SQL |
| Offline Support | ✅ Built-in | ⚠️ Manual sync |
| Cost | 💰 Read-heavy expensive | 💰💰 DTU-based |
| Scalability | ✅ Auto-scaling | ⚠️ Manual scaling |

**Recommendation for Faz 2:**
- **Short-term:** Dual-write (Firestore real-time + SQL historical)
- **Long-term:** Migrate to SQL + SignalR/WebSocket (Faz 3)

---

## ✅ Faz 2 Implementation Roadmap

### Week 1-2: DM Dual-Write
- [ ] Create SQL tables (Messages, Conversations)
- [ ] Create stored procedures (send, get, mark-read)
- [ ] Modify `sendMessage` Cloud Function for dual-write
- [ ] Migration script (existing DM → SQL)
- [ ] Integration tests

### Week 3-4: Timeline Dual-Write
- [ ] Create SQL tables (TimelineEvents, UserFollowTimeline)
- [ ] Create stored procedures (create event, get feed)
- [ ] Modify timeline triggers for dual-write
- [ ] Migration script
- [ ] Performance testing (fan-out load)

### Week 5-6: Notifications Dual-Write
- [ ] Create SQL table (Notifications)
- [ ] Create stored procedures
- [ ] Modify notification service for dual-write
- [ ] FCM integration testing

### Week 7-8: Validation & Monitoring
- [ ] Consistency checker (Firestore ↔ SQL)
- [ ] Performance benchmarking
- [ ] Alert system for dual-write failures
- [ ] Documentation

---

**Not:** Bu sadece plan aşamasıdır. Faz 1 production'da stable olduktan sonra implementation başlayacaktır.
