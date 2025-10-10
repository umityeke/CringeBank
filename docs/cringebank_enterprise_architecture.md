# CringeBank Enterprise Mimari & Akış Diyagramı

Aşağıdaki diyagram, CringeBank hibrit mimarisinin güncel akışını Firestore ↔ MSSQL senkronizasyonu, CringeYarışma/Drawer/Store (Escrow) süreçleri ve enterprise güvenlik katmanıyla birlikte gösterir. Diyagramdaki düzeltmeler:

- Outbox consumer yalnızca Firestore güncellemelerini tetikler; medya dosyaları doğrudan istemciden Firebase Storage'a yüklenir.
- CringeStore sipariş/escrow adımlarında MSSQL güncellemelerinin Firestore görünüm katmanına nasıl geri aktarıldığı explicit olarak belirtilmiştir.

```mermaid
flowchart TD

%% === KULLANICI KATMANI ===
A[👤 Kullanıcı (Mobil/Web App)] --> B[Flutter Client]
B --> C[Firebase SDKs\n(Auth + Firestore + FCM)]
B --> G[(Firebase Storage\n(client upload))]

%% === BACKEND KATMANI ===
C --> D[🌐 Backend API Layer\n(Node.js / .NET / Cloud Functions)]
D --> E[(MSSQL SoT)]
D --> F[(Firestore Realtime)]
D --> H[(FCM Notifications)]

%% === OUTBOX & SENKRON ===
E --> I[📤 Outbox Events\n(UserCreated, RewardCreated, WalletReleased...)]
I --> J[⚙️ Outbox Consumer\n(idempotent, backoff, retry)]
J --> F

%% === FIRESTORE & UI YANSIMALARI ===
F --> K[📱 Kullanıcı Arayüzü\n(profil, yarışma, drawer, store görünümü)]

%% === GÜVENLİK KATMANI ===
D --> L[🔐 Security & Compliance\n(MFA, Rate Limit, Audit Logs, App Check)]

%% === CRINGEYARIŞMA AKIŞI ===
subgraph "🏆 CringeYarışma"
    Y1[Admin → MSSQL Competitions insert]
    Y2[Competition status = published]
    Y3[Outbox: CompetitionPublished]
    Y4[Cloud Function broadcast_competition]
    Y5[📣 Push (FCM) & In-App Message → Tüm Kullanıcılara]
    Y6[📱 Kullanıcı Tahmin Gönderir → Firestore guesses/{uid}/{competitionId}]
    Y7[⏰ Süre dolunca → Cloud Function finalize_competition]
    Y8[MSSQL: Rewards oluşturulur]
    Y9[Outbox: RewardCreated → Drawer’a yansır]
end

Y1 --> Y2 --> Y3 --> Y4 --> Y5
Y5 --> Y6 --> Y7 --> Y8 --> Y9

%% === CRINGEDRAWER (ÖDÜL SANDIĞI) ===
subgraph "🎁 CringeDrawer"
    D1[Outbox RewardCreated → Firestore /users/{uid}/drawer_items]
    D2[📱 Kullanıcı Drawer ekranında ödül görür]
    D3[Kullanıcı kodu gösterir → RewardRedemptions log (MSSQL)]
    D4[Status değişir → new → used]
end

Y9 --> D1
D1 --> D2 --> D3 --> D4

%% === CRINGESTORE (SATIŞ & ESCROW) ===
subgraph "🛒 CringeStore"
    S1[Satıcı ürün bilgisi + satış CG girer]
    S2[Ön izleme: kesintiler sonrası net CG hesaplanır]
    S3[Ürün satışa çıkar → MSSQL Products/Orders insert]
    S4[Alıcı satın al → WalletEntries (HOLD)]
    S5[Ürün kargoda → DELIVERING]
    S6[Alıcı 'Teslim Aldım' tıklar]
    S7[Escrow release → MSSQL WalletEntries credit/debit]
    S8[Komisyon + vergi ayrılır → CringeBank cüzdanı]
    S9[Satıcıya net CG aktarılır]
end

S1 --> S2 --> S3 --> S4 --> S5 --> S6 --> S7 --> S8 --> S9
S4 -. Outbox → Firestore store_orders/store_wallets .-> F
S7 -. Outbox → Firestore store_orders/store_wallets .-> F

%% === BİLDİRİMLER VE LOGS ===
subgraph "📡 Notifications & Logs"
    N1[FCM Push Bildirimleri]
    N2[In-App Messages]
    N3[AuditLogs & SecurityEvents (MSSQL)]
end

H --> N1
F --> N2
L --> N3
D9[Rollback & Feature Flags\n(Disable → Reset → Replay)]:::rollback

%% === GÜVENLİK & ENTERPRISE ===
subgraph "🔒 Enterprise Guardrails"
    G1[MFA & Passkey Enforced]
    G2[Rate Limit & IP Hashing]
    G3[AppCheck & reCAPTCHA]
    G4[KVKK/GDPR Masking]
    G5[Audit Trail (kim, ne, ne zaman)]
end

L --> G1 & G2 & G3 & G4 & G5

classDef rollback fill=#2D2D2D,stroke=#FFD54F,stroke-width=2px,color=#FFD54F;
```

## Yapının Temel Mantığı

| Katman | Sistem | Rol |
| --- | --- | --- |
| Kullanıcı / Mobil | Flutter + Firebase SDK | Uygulama arayüzü, gerçek zamanlı deneyim |
| Uygulama Sunucusu | Node.js / .NET | İş mantığı, kimlik doğrulama, denetim |
| Veri Katmanı (SoT) | MSSQL | Finans, güvenlik, log, audit, denetim |
| Görünüm Katmanı | Firestore | UI performansı, denormalize görünüm |
| Senkronizasyon | Outbox Event + Function Consumer | MSSQL → Firestore yansıtma, rollback |
| Depolama | Firebase Storage (client upload) | Medya, ürün görselleri |
| Bildirim | FCM + In-App Message | Push + uygulama içi bilgilendirme |
| Güvenlik | MFA, Audit, App Check | Üst seviye enterprise koruma |

## Özet

- MSSQL = Gerçek kaynak (Source of Truth)
- Firestore = Hızlı görünüm katmanı
- Her yazma işlemi → Outbox event üretir → Function consumer Firestore’a yansıtır.
- Ürün görselleri istemci tarafından Firebase Storage’a yüklenir; backend yalnızca metadata doğrular.
- Yarışma, satış, cüzdan, ödül gibi kritik işlemler loglanır ve rollback planı vardır.
- Push + In-App message kullanıcıyı bilgilendirir.
- AppCheck + MFA + audit = veri bütünlüğü garantisi.
