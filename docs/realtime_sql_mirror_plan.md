# ⚡ Gerçek Zamanlı Modüller SQL Aynası Planı

## 🎯 Amaç

Direct Message (DM) ve takip (follow) etkinliklerini Firestore odaklı gerçek zamanlı altyapıdan Microsoft SQL Server tabanlı kalıcı bir depoya taşımak. Geçiş boyunca okuma istekleri kesintisiz devam ederken, yazma akışını çift yönlü (Firestore + SQL) hale getirip orta vadede SQL üzerinden gerçek zamanlı yayın (SignalR/WebSocket) katmanına geçişi mümkün kılmak.

---

## 🧱 Kapsam ve Fazlar

1. **SQL Mirror MVP**
   - DM konuşma ve mesaj içeriklerini SQL’e yazan yeni tablo şeması.
   - Takip/follow olayları için SQL tablo + audit trail.
   - Azure Service Bus tabanlı event kuyruğu katmanı.
2. **Çift Yazma & Sync Servisi**
   - Firestore → SQL senkronizasyonu yapan arka plan fonksiyonları.
   - Flutter istemcisinde çift yazma desteği (Firestore + callable → SQL).
3. **Gerçek Zamanlı Okuma Dönüşümü**
   - SignalR/WebSocket gateway katmanı.
   - Flutter tarafında SQL kaynaklı canlı akış okuyucusu.
4. **Tam SQL’e Geçiş**
   - Firestore koleksiyonlarını read-only moda almak.
   - Yeni audit ve observability panellerini devreye almak.

---

## 🗄️ SQL Şema Tasarımı

### 1. Direct Message Tabloları

| Tablo | Açıklama | Önemli Alanlar |
| --- | --- | --- |
| `dbo.DmConversation` | İkili veya grup DM konuşmalarını içerir. | `ConversationId (PK, bigint identity)`, `Type` (direct/group), `CreatedAt`, `UpdatedAt`, `LastMessageId`, `ParticipantHash` (deterministik hash), `FirestoreId` (legacy referans) |
| `dbo.DmParticipant` | Konuşma üyeleri ve rol bilgisi. | `ConversationId (FK)`, `UserId`, `Role` (owner/member), `JoinedAt`, `MuteState`, `ReadPointerMessageId`, `FirestorePointer` |
| `dbo.DmMessage` | Mesaj gövdesi ve metadata. | `MessageId (PK)`, `ConversationId (FK)`, `AuthorUserId`, `BodyText`, `AttachmentJson`, `ExternalMediaJson`, `CreatedAt`, `EditedAt`, `DeletedAt`, `ClientMessageId`, `FirestoreId` |
| `dbo.DmMessageAudit` | Mesaj düzenleme/silme geçmişi. | `AuditId`, `MessageId`, `Action`, `PerformedBy`, `PayloadJson`, `CreatedAt` |
| `dbo.DmBlock` | Kullanıcı engelleme kayıtları. | `UserId`, `TargetUserId`, `CreatedAt`, `RevokedAt`, `Source` (client/admin) |

### 2. Takip (Follow) Tabloları

| Tablo | Açıklama | Önemli Alanlar |
| --- | --- | --- |
| `dbo.FollowEdge` | Kullanıcılar arası takip ilişkisi. | `FollowerUserId`, `TargetUserId`, `CreatedAt`, `State` (pending/accepted/blocked), `Source` (mobile/web/admin) |
| `dbo.FollowEvent` | Takip olay günlükleri ve bildirim tetikleyicileri. | `EventId`, `FollowerUserId`, `TargetUserId`, `EventType` (request/accept/remove/block/unblock), `CreatedAt`, `CorrelationId`, `MetadataJson` |
| `dbo.FollowRecommendation` | Opsiyonel: öneri motoru için anlık snapshot. | `RecommendationId`, `UserId`, `SuggestedUserId`, `Score`, `Source` |

### 3. Kuyruk & Log Tabloları

| Tablo | Açıklama |
| --- | --- |
| `dbo.RealtimeMirrorCheckpoint` | Sync servislerinin Firestore üzerinde hangi timestamp’e kadar işlendiğini tutar (`Module`, `Shard`, `LastProcessedAt`, `CursorToken`). |
| `dbo.RealtimeMirrorDeadLetter` | Kuyruğa alınamayan veya SQL’e yazarken hata veren olayları saklar. |
| `dbo.RealtimeMirrorMetrics` | Batch süreleri, işlenen kayıt sayıları, latency metrikleri. |

> **Not:** Tüm tablolarda `CreatedAt` ve `UpdatedAt` alanları UTC `datetimeoffset` olarak tutulmalı; idempotent insert/update işlemleri için `ClientMessageId` veya `CorrelationId` zorunlu.

---

## 📨 Event Kuyruğu Yapısı

- **Teknoloji:** Azure Service Bus (Topic + Subscription).
- **Topic:** `realtime-mirror` – DM ve follow olaylarını tek topic altında topla.
- **Subscriptions:**
  - `sql-writer` → SQL stored procedure çağrıları.
  - `monitoring` → Application Insights/Log Analytics için telemetri.
  - `dead-letter` → Otomatik olarak başarısız mesajları taşır.
- **Mesaj Şeması (`CloudEvent` uyumlu):**

  ```json
  {
    "id": "<uuid>",
    "source": "firestore://conversations/{conversationId}",
    "type": "dm.message.created",
    "time": "2025-10-08T12:34:56.000Z",
    "specversion": "1.0",
    "data": {
      "firestoreId": "abc123",
      "conversationId": "userA_userB",
      "payload": { /* message snapshot */ },
      "op": "create"
    }
  }
  ```

- **Retry Politikası:** 5 deneme, exponential backoff; sonrasında dead-letter kuyruğuna.
- **Güvenlik:** Managed Identity + Azure AD RBAC; her abonelik için ayrı SAS anahtarı bulunmaz.

---

## 🔄 Sync Servisleri

### 1. Firestore → Service Bus Publisher

- **Implementation:** Cloud Functions (Node.js) veya Cloud Run job.
- **Trigger:** Firestore `onWrite` tetikleri (`conversations/{id}` ve `conversations/{id}/messages/{mid}` koleksiyonları, `follows/{userId}/targets/{targetId}` dokümanları).
- **İş Akışı:**
  1. Firestore event payload’ını normalize et (timestamp’leri ISO8601, boolean/string tip dönüşümleri).
  2. `RealtimeMirrorCheckpoint` tablo kaydını güncelle (idempotency).
  3. Azure Service Bus topic’ine `CloudEvent` formatında yayınla.

### 2. Service Bus → SQL Writer

- **Implementation:** Azure Functions (Service Bus trigger) veya Node.js worker.
- **Adımlar:**
  1. Mesaj başlığına göre stored procedure seç (`dm_message_upsert`, `follow_edge_upsert`, vb.).
  2. SQL transaction içinde upsert işlemini gerçekleştir.
  3. Sonuçları Application Insights’a custom event olarak yaz.
  4. Başarısız olursa dead-letter kuyruğuna gönder.
  5. `functions/realtime_mirror/sql_writer_worker.js` betiği ile lokal veya container ortamında çalıştır (`npm run mirror:sql-writer`).
  6. Event türü → stored procedure eşleşmesi:
     - `dm.conversation.{create|update}` → `sp_StoreMirror_UpsertDmConversation`
     - `dm.message.{create|update}` → `sp_StoreMirror_UpsertDmMessage`
     - `dm.message.delete` → `sp_StoreMirror_DeleteDmMessage`
     - `follow.edge.{create|update}` → `sp_StoreMirror_UpsertFollowEdge`
     - `follow.edge.delete` → `sp_StoreMirror_DeleteFollowEdge`

### 3. Backfill & Reconciliation Worker

- **Amaç:** Tarihsel veriyi Firestore’dan SQL’e toplu aktarmak.
- **Çalışma:** Batch halinde Firestore sorguları → Service Bus queue (veya doğrudan SQL bulk insert).
- **Checkpoint:** `RealtimeMirrorCheckpoint` ile hangi `updatedAt` değerine kadar işlendiğini kaydet.

---

## 📱 Flutter Çift Yazma Adaptasyonu

### 1. Yazma Yolu

- `DirectMessageService.sendMessage` çağrılarına SQL aynası için ek payload:
  - Firebase Callable `sendMessage` yanıtında `shouldMirrorSql` alanı dönerse, Flutter aynı payload’ı `sqlGatewayDmSend` callable’ına da iletir.
  - Medya yüklemeleri (Firebase Storage) sonrası SQL’e gönderilen mesaj, attachment metadata’yı da içerir.
- `blockUser`, `ensureConversation`, `follow/unfollow` işlemleri için de eşdeğer SQL callable’ları eklenir.

### 2. Okuma Yolu (Geçiş Süreci)

- **Aşama 1:** Firestore’dan okumaya devam; SQL yazma yalnızca arka planda doğrulama amaçlı.
- **Aşama 2:** Feature flag (`USE_SQL_DM_READS`) ile belirli kullanıcı segmentleri SQL kaynaklı REST endpoint’ten beslenir.
- **Aşama 3:** SignalR/WebSocket gateway devreye girer; Flutter `Stream` kaynaklarını bu gateway’den alır.

### 3. Hata Yönetimi

- Firestore yazma başarılı, SQL yazma başarısız olursa kullanıcıya hata dönülmez; `RealtimeMirrorDeadLetter` üzerinden izleme.
- SQL yazma başarısızlığı kritik senaryoda (ör. DM ayakta kalmalı) feature flag ile fallback.

---

## 🧪 Validasyon ve Test Stratejisi

### 1. Otomasyon Testleri

| Katman | Araç | Senaryolar |
| --- | --- | --- |
| Unit | Jest (Functions) | Firestore trigger → Service Bus publisher payload dönüşümleri |
| Integration | Azure Functions + MSSQL test container | Service Bus mesajı → Stored procedure upsert, concurrency |
| Client | Flutter `test/services/direct_message_service_test.dart` | Çift yazma çağrıları, hata senaryoları |
| Load | k6 / Locust | DM gönderme akışı sırasında latency < 200 ms hedefi |

### 2. Data Consistency Checker

- **Araç:** Node.js script (`scripts/dm_follow_consistency.js`).
- **Fonksiyon:** Firestore ve SQL verilerini karşılaştır; eksik kayıt, farklı timestamp, attachment mismatch.
- **Çalıştırma:** Nightly cron + manuel tetikleme.

### 3. Performans İzleme

- Application Insights metric: `SqlMirrorLatencyMs` (publish → SQL commit).
- Service Bus Topic telemetry: `ActiveMessageCount`, `DeadLetterCount`.
- Flutter tarafında `DmSendLatency` (UI start → callable completion) analizi.

### 4. Canary & Rollout

1. `USE_SQL_DM_WRITE_MIRROR=true` ile %5 kullanıcı segmenti.
2. Telemetry + consistency raporları temizse %50 -> %100.
3. SQL okuma pathway’i için ayrı canary feature flag.

### 5. SQL Entegrasyon Test Checklist’i

1. **Ortamı başlat:** `docker compose -f backend/docker-compose.yml up sql -d` (veya Azure SQL dev instance).
2. **Şema dağıtımı:** `backend/scripts/deploy_realtime_mirror.ps1` ile tablo + SP paketini uygula.
3. **Test verisi:** `functions/scripts/fixtures/realtime_mirror_seed.json` dosyasındaki örnek dataset’i gerekirse güncelle.
4. **Seed betiği:** `npm run mirror:seed -- --dry-run` ile doğrula, ardından SQL’e gerçek yazma için `npm run mirror:seed` çalıştır.
5. **Test senaryoları:**

    - Service Bus mesajı → `sp_StoreMirror_UpsertDmMessage` çağrısı (success + duplicate).
    - Delete event → `sp_StoreMirror_DeleteDmMessage` log ve tombstone güncellemesi.
    - Follow edge create/delete → `FollowEdge` state ve `FollowEvent` günlükleri.

6. **Doğrulama script’i:** `scripts/dm_follow_consistency.js` konsolu ile Firestore snapshot’ı ve SQL kayıtlarını karşılaştır (`npm run mirror:consistency -- --conversation=<id>`).

7. **CI/CD entegrasyonu:** GitHub Actions’ta SQL konteynerı ayağa kaldırıp yukarıdaki betikleri sırasıyla koştur.

---

## 🔐 Güvenlik ve Uyumluluk

- Managed Identity ile Service Bus ve SQL erişimi.
- DM içerikleri için **rest at encryption** (`Always Encrypted` veya column-level encryption`).
- GDPR/CCPA erişim talepleri: SQL’deki DM kayıtları için `DeleteRequestQueue` tasarımı (ayrı dokümante edilecek).

---

## 🛠️ Operasyonel Gereksinimler

- **Infra:** Azure Service Bus Standard tier, Azure Functions Premium plan (soğuk başlatmayı minimize etmek için).
- **Infra as Code:** Bicep/Terraform modülü; topic, subscription, IAM rolleri.
- **Runbook:** Dead-letter kuyruğu boşaltma, checkpoint reset, bulk backfill prosedürleri.
- **Dağıtım Paketleri:**
  - `backend/scripts/deploy_realtime_mirror.sqlcmd` → tablo + prosedür paketini `sqlcmd` üzerinden çalıştırır.
  - `backend/scripts/deploy_realtime_mirror.ps1` → sunucu/DB parametreleriyle sqlcmd çağrısını otomatikleştirir.
  - Örnek komut: `sqlcmd -S <sunucu> -d <veritabani> -G -b -i deploy_realtime_mirror.sqlcmd`.
- **CI/CD Entegrasyonu:** PowerShell betiği GitHub Actions, Azure DevOps veya Octopus pipeline’ına kolayca dahil edilebilir.
- **Alerting:**
  - Service Bus `DeadLetterCount > 10`
  - SQL `RealtimeMirrorDeadLetter` insert > 0
  - Flutter `DmSqlMirrorFailure` Sentry event rate > eşik

---

## 📅 Takvim (T+ Haftalar)

| Hafta | Milestone |
| --- | --- |
| T | Şema tasarımı, Service Bus oluşturma, stored procedure prototipleri |
| T+1 | Firestore trigger publisher + SQL writer fonksiyonu MVP |
| T+2 | Flutter çift yazma entegrasyonu, otomasyon testleri |
| T+3 | Backfill & consistency checker, load test |
| T+4 | Canary rollout + SignalR POC |

---

## ✅ Çıktılar

- SQL şema migrasyon scriptleri (`backend/scripts/migrations/20251008_07_create_dm_follow_mirror_tables.sql`).
- SQL mirror stored procedure’leri:
  - `backend/scripts/stored_procedures/sp_StoreMirror_UpsertDmConversation.sql`
  - `backend/scripts/stored_procedures/sp_StoreMirror_UpsertDmMessage.sql`
  - `backend/scripts/stored_procedures/sp_StoreMirror_DeleteDmMessage.sql`
  - `backend/scripts/stored_procedures/sp_StoreMirror_UpsertFollowEdge.sql`
  - `backend/scripts/stored_procedures/sp_StoreMirror_DeleteFollowEdge.sql`
- Service Bus + Azure Functions kodu (`functions/realtime_mirror/*`).
- Flutter servis güncellemeleri (`lib/services/direct_message_service.dart`, `lib/services/follow_service.dart`).
- Validasyon scriptleri (`scripts/dm_follow_consistency.js`).
- Operasyonel runbook ve telemetry dashboard’ları.
