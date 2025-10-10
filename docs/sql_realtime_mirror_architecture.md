# SQL Gerçek Zamanlı Ayna Mimarisi

Bu doküman, DM (Direct Message) ve takip (follow) modülleri için Firestore üzerinde üretilen değişikliklerin Azure SQL aynasına düşük gecikmeli şekilde aktarılmasını sağlayan Service Bus temelli mimariyi özetler.

## Amaçlar

- Firestore üzerinde gerçekleştirilen her DM mesajı, DM konuşması ve takip kenarı (follow edge) değişikliğinin eş zamanlı olarak SQL aynasında tutulması.
- Aynadaki veriyi Flutter istemcilerinin okuyabileceği birincil kaynak haline getirmek için altyapıyı hazırlamak.
- İleride SignalR/WebSocket üzerinden gerçek zamanlı SQL okuma kanalına geçişe altyapı oluşturmak.

## Bileşenler

1. **Firestore Tetikleyicileri** (`functions/index.js`)
   - `mirrorDmMessages`, `mirrorDmConversations`, `mirrorFollowEdges` triggerları ilgili koleksiyonlarda `onWrite` tetiklenir.
   - Her tetikleyici, `realtime_mirror/event_builder` yardımıyla olayı (CloudEvent) serileştirir.
   - Olaylar `realtime_mirror/publisher.publishEvent` aracılığıyla Azure Service Bus topic'ine gönderilir.

2. **Event Formatı** (`realtime_mirror/event_builder.js`)
   - `type`: `dm.message.create|update|delete`, `dm.conversation.create|update`, `follow.edge.create|update|delete`.
   - `id`: `eventType:source:firestoreEventId:entropy` formatında benzersiz kimlik.
   - `data`:
     - `operation`: `create|update|delete`.
     - `document` / `previousDocument`: Firestore doküman payload'ları (JSON string olarak saklanır).
     - Kimlik alanları (`conversationId`, `messageId`, `userId`, `targetId`).

3. **Service Bus Katmanı** (`realtime_mirror/service_bus.js`)
   - Topic: `SERVICEBUS_TOPIC_REALTIME_MIRROR` (varsayılan `realtime-mirror`).
   - Subscription'lar:
     - `sql-writer`: SQL güncelleme işlemlerini yürütür.
     - `monitoring`: Opsiyonel izleme/telemetri tüketicileri.
   - `publishRetryCount` ile yeniden deneme sayısı yapılandırılabilir (default 3). Exponential backoff uygulanır.

4. **SQL Writer Processörü** (`realtime_mirror/processor.js` ve `sql_writer_worker.js`)
   - Service Bus subscription'ından mesajları `peekLock` modu ile çeker.
   - Her olay için ilgili stored procedure seçilir:
     - `sp_StoreMirror_UpsertDmMessage`
     - `sp_StoreMirror_UpsertDmConversation`
     - `sp_StoreMirror_DeleteDmMessage`
     - `sp_StoreMirror_UpsertFollowEdge`
     - `sp_StoreMirror_DeleteFollowEdge`
   - MSSQL connection pool `sql_gateway/pool` üzerinden yönetilir.
   - Başarılı işlendiğinde mesaj `complete`, hata durumunda `abandon` edilir; Service Bus retry politikası devreye girer.

5. **SQL Şeması Önerisi** (özet)
   - `DmConversationsMirror`: `ConversationId`, `OwnerId`, `PeerIds`, `LastMessageAt`, `LastMessagePreview`, `LastMessageAuthorId`, `UpdatedAt`.
   - `DmMessagesMirror`: `ConversationId`, `MessageId`, `AuthorId`, `Body`, `Media`, `CreatedAt`, `UpdatedAt`, `DeletedAt`.
   - `FollowEdgesMirror`: `UserId`, `TargetId`, `CreatedAt`, `UpdatedAt`, `EdgeType`.
   - Stored procedure'ler idempotent olacak şekilde UPSERT/DELETE mantığıyla günceller.

6. **Ortam Değişkenleri**
   - `SERVICEBUS_CONNECTION_STRING`
   - `SERVICEBUS_TOPIC_REALTIME_MIRROR`
   - `SERVICEBUS_SUBSCRIPTION_SQL_WRITER`
   - `SQL_PROC_DM_MESSAGE_UPSERT` vb. stored procedure adları
   - `USE_SQL_DM_WRITE_MIRROR` flag'i (Firestore -> SQL aynasına yazmayı aç/kapa)

## İş Akışı

1. Kullanıcı uygulamada yeni mesaj gönderir → Firestore dokümanı oluşturulur.
2. Firestore trigger'ı tetiklenir, olay CloudEvent formatında hazırlanır.
3. Service Bus topic'ine gönderilen olay, SQL writer subscription'ı tarafından alınır.
4. Stored procedure çağrısı ile ilgili tablo güncellenir.
5. Flutter istemcisi, feature flag açık ise SQL aynasından okuma yapar; kapalı ise Firestore dinleyicilerine geri döner.

## İyileştirme Alanları

- **Dead-letter Kuyruğu**: Service Bus DLQ izlenmeli, `SERVICEBUS_DEADLETTER_ALERT_THRESHOLD` aşıldığında uyarı oluşturulmalı.
- **Monitoring**: SQL writer çalışması için Application Insights / Crashlytics log korelasyonu eklenebilir.
- **Idempotency**: Stored procedure'lerin `EventId` veya `MessageId` bazlı idempotent davranışı garanti edilmeli.
- **Realtime Tüketici**: Uzun vadede SignalR/WebSocket subscriber ile Service Bus olaylarını gerçek zamanlıya çevirmek hedefleniyor. Bu aşamada SQL read path pollinga devam ediyor.

## Dağıtım Planı

1. Azure Service Bus topic ve subscription'ları oluştur.
2. Firebase Functions ortam değişkenlerini güncelle (`functions:config:set` veya CI/CD secret store).
3. SQL writer worker'ı (Cloud Run / Functions) `sql_writer_worker.js` ile başlat; container veya cron tabanlı olabilir.
4. Stored procedure'leri veritabanına yayınla ve versiyon kontrolünde tut.
5. `USE_SQL_DM_WRITE_MIRROR` flag'ini kademeli olarak aç; Crashlytics ve Service Bus metric'lerini izle.
6. Flutter feature flag'leri üzerinden SQL okuma yolunu yavaş yavaş etkinleştir.

## Test Stratejisi

- **Unit Test**: `realtime_mirror/__tests__` altında event builder ve publisher için Jest testleri.
- **Integration Test**: Service Bus emulator veya canlı SB ile uçtan uca mesaj gönderip SQL'e yazdığını doğrulayan test senaryosu eklenmeli.
- **Latency Ölçümü**: Flutter `SqlMirrorLatencyMonitor` metrikleri ve Functions log'ları birleşik dashboard'da takip edilmeli; hedef < 200ms.

---
Bu mimari plan, DM ve takip verilerinin SQL aynasına güvenilir şekilde akmasını sağlar ve ileride tam SQL tabanlı gerçek zamanlı deneyime geçiş için temel oluşturur.
