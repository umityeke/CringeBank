# CringeBank SQL Schema Plan

**Last updated:** 2025-10-20

This document captures the first-pass relational model for the new CringeBank backend (SQL Server 2017+). It follows the architectural brief and is meant to be the source of truth while generating EF Core entities and migrations.

## 1. Conventions

- **Database:** `CringeBank`
- **Schemas:** logical domains (e.g. `auth`, `social`, `chat`, `wallet`, `commerce`, `moderation`, `notify`, `admin`, `syscfg`)
- **Primary keys:** `BIGINT IDENTITY(1,1)` unless noted. Surrogate **public identifiers** use `UNIQUEIDENTIFIER` with `NEWSEQUENTIALID()` default (exposed via API).
- **Timestamps:** `DATETIME2(3)` UTC. Columns: `created_at`, `updated_at`, optional `deleted_at` for soft deletes.
- **Booleans:** `BIT`.
- **Monetary values:** `DECIMAL(18,2)` unless domain requires higher precision.
- **String encoding:** `NVARCHAR` with explicit max length. Use `NVARCHAR(256)` for emails, `NVARCHAR(64)` for usernames, etc.
- **Audit:** For key tables include `created_by_user_id` when actions are user-initiated.
- **Indices:** `IX_<table>_<columns>`.

## 2. auth schema

### 2.1 auth.Users

| Column | Type | Constraints |
| --- | --- | --- |
| id | BIGINT IDENTITY | PK, clustered |
| public_id | UNIQUEIDENTIFIER | NOT NULL, UNIQUE DEFAULT NEWSEQUENTIALID() |
| email | NVARCHAR(256) | NOT NULL, UNIQUE |
| email_normalized | NVARCHAR(256) | NOT NULL |
| username | NVARCHAR(64) | NOT NULL, UNIQUE |
| username_normalized | NVARCHAR(64) | NOT NULL |
| password_hash | VARBINARY(MAX) | NULL (if magic-link only) |
| password_salt | VARBINARY(128) | NULL |
| auth_provider | NVARCHAR(32) | NOT NULL DEFAULT 'sql' (sql/firebase) |
| phone | NVARCHAR(32) | NULL |
| status | TINYINT | NOT NULL DEFAULT 1 (1:active,2:suspended,3:banned) |
| last_login_at | DATETIME2(3) | NULL |
| created_at | DATETIME2(3) | NOT NULL DEFAULT SYSUTCDATETIME() |
| updated_at | DATETIME2(3) | NOT NULL DEFAULT SYSUTCDATETIME() |

Indices: `IX_Users_EmailNormalized`, `IX_Users_UsernameNormalized` (UNIQUE). Trigger or computed column to maintain normalized values.

### 2.2 auth.UserProfiles

| Column | Type | Constraints |
| id | BIGINT IDENTITY | PK |
| user_id | BIGINT | FK -> auth.Users(id) ON DELETE CASCADE |
| display_name | NVARCHAR(128) | NULL |
| bio | NVARCHAR(512) | NULL |
| avatar_url | NVARCHAR(512) | NULL |
| banner_url | NVARCHAR(512) | NULL |
| verified | BIT | NOT NULL DEFAULT 0 |
| location | NVARCHAR(128) | NULL |
| website | NVARCHAR(256) | NULL |
| created_at | DATETIME2(3) | DEFAULT SYSUTCDATETIME() |
| updated_at | DATETIME2(3) | DEFAULT SYSUTCDATETIME() |

Unique: `UK_UserProfiles_UserId`.

### 2.3 auth.UserSecurity

Stores MFA/secrets.

| Column | Type | Constraints |
| user_id | BIGINT | PK, FK -> auth.Users(id) |
| otp_secret | VARBINARY(256) | NULL |
| otp_enabled | BIT | DEFAULT 0 |
| magic_code_hash | VARBINARY(256) | NULL |
| magic_code_expires_at | DATETIME2(3) | NULL |
| refresh_token_hash | VARBINARY(256) | NULL |
| refresh_token_expires_at | DATETIME2(3) | NULL |
| last_password_reset_at | DATETIME2(3) | NULL |

### 2.4 auth.UserBlocks

| Column | Type | Constraints |
| id | BIGINT IDENTITY | PK |
| blocker_user_id | BIGINT | FK -> auth.Users(id) |
| blocked_user_id | BIGINT | FK -> auth.Users(id) |
| created_at | DATETIME2(3) | DEFAULT SYSUTCDATETIME() |

Unique: `UX_UserBlocks_Blocker_Blocked`. Index on `blocked_user_id`.

### 2.5 auth.Follows

| Column | Type | Constraints |
| id | BIGINT IDENTITY | PK |
| follower_user_id | BIGINT | FK -> auth.Users |
| followee_user_id | BIGINT | FK -> auth.Users |
| created_at | DATETIME2(3) | DEFAULT SYSUTCDATETIME() |

Unique: `UX_Follows_Follower_Followee`. Index on `(followee_user_id, created_at DESC)` for follower listing.

### 2.6 auth.DeviceTokens

| Column | Type | Constraints |
| id | BIGINT IDENTITY | PK |
| user_id | BIGINT | FK -> auth.Users |
| platform | NVARCHAR(32) | NOT NULL (ios/android/web) |
| token | NVARCHAR(512) | NOT NULL |
| created_at | DATETIME2(3) | DEFAULT SYSUTCDATETIME() |
| last_used_at | DATETIME2(3) | NULL |

Unique: `UX_DeviceTokens_User_Token`.

### 2.7 auth.Roles & auth.UserRoles

Roles table stores predefined roles (user/categoryAdmin/superAdmin).

| Column | Type |
| --- | --- |
| id | INT IDENTITY PRIMARY KEY |
| name | NVARCHAR(64) UNIQUE |
| description | NVARCHAR(256) NULL |

`auth.UserRoles` bridging `user_id` to `role_id` with unique composite.

## 3. social schema

### 3.1 social.Posts

| Column | Type | Constraints |
| id | BIGINT IDENTITY | PK |
| public_id | UNIQUEIDENTIFIER | DEFAULT NEWSEQUENTIALID(), UNIQUE |
| user_id | BIGINT | FK -> auth.Users |
| type | TINYINT | NOT NULL |
| text | NVARCHAR(2000) | NULL |
| visibility | TINYINT | NOT NULL DEFAULT 0 (0:public,1:followers,2:private) |
| likes_count | INT | DEFAULT 0 |
| comments_count | INT | DEFAULT 0 |
| saves_count | INT | DEFAULT 0 |
| created_at | DATETIME2(3) | DEFAULT SYSUTCDATETIME() |
| updated_at | DATETIME2(3) | DEFAULT SYSUTCDATETIME() |
| deleted_at | DATETIME2(3) | NULL |

Index: `(user_id, created_at DESC)`, `(created_at DESC, id DESC)` for home feed.

### 3.2 social.PostMedia

| Column | Type | Constraints |
| id | BIGINT IDENTITY | PK |
| post_id | BIGINT | FK -> social.Posts(id) ON DELETE CASCADE |
| url | NVARCHAR(512) | NOT NULL |
| mime | NVARCHAR(64) | NULL |
| width | INT | NULL |
| height | INT | NULL |
| order_index | TINYINT | NOT NULL DEFAULT 0 |

### 3.3 social.PostLikes

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| post_id | BIGINT NOT NULL REFERENCES social.Posts(id) ON DELETE CASCADE |
| user_id | BIGINT NOT NULL REFERENCES auth.Users(id) ON DELETE CASCADE |
| created_at | DATETIME2(3) DEFAULT SYSUTCDATETIME() |

Unique: `UX_PostLikes_Post_User`.

### 3.4 social.PostComments

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| post_id | BIGINT NOT NULL REFERENCES social.Posts(id) ON DELETE CASCADE |
| parent_comment_id | BIGINT NULL REFERENCES social.PostComments(id) |
| user_id | BIGINT NOT NULL REFERENCES auth.Users(id) |
| text | NVARCHAR(1000) NOT NULL |
| like_count | INT NOT NULL DEFAULT 0 |
| created_at | DATETIME2(3) DEFAULT SYSUTCDATETIME() |
| updated_at | DATETIME2(3) DEFAULT SYSUTCDATETIME() |
| deleted_at | DATETIME2(3) NULL |

Index: `(post_id, created_at ASC)`.

### 3.5 social.CommentLikes

Tracks comment likes.

### 3.6 social.PostSaves

Bookmark table linking users to posts.

### 3.7 social.Tags & social.PostTags

Optional: allow hashtags.

## 4. chat schema

### 4.1 chat.Conversations

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| public_id | UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID() UNIQUE |
| is_group | BIT NOT NULL |
| title | NVARCHAR(128) NULL |
| created_by_user_id | BIGINT NOT NULL REFERENCES auth.Users(id) |
| created_at | DATETIME2(3) DEFAULT SYSUTCDATETIME() |
| updated_at | DATETIME2(3) DEFAULT SYSUTCDATETIME() |

### 4.2 chat.ConversationMembers

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| conversation_id | BIGINT REFERENCES chat.Conversations(id) ON DELETE CASCADE |
| user_id | BIGINT REFERENCES auth.Users(id) ON DELETE CASCADE |
| role | TINYINT NOT NULL DEFAULT 0 |
| joined_at | DATETIME2(3) DEFAULT SYSUTCDATETIME() |
| last_read_message_id | BIGINT NULL |
| last_read_at | DATETIME2(3) NULL |

Unique: `(conversation_id, user_id)`.

### 4.3 chat.Messages

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| conversation_id | BIGINT REFERENCES chat.Conversations(id) ON DELETE CASCADE |
| sender_user_id | BIGINT REFERENCES auth.Users(id) |
| body | NVARCHAR(2000) NULL |
| deleted_for_all | BIT NOT NULL DEFAULT 0 |
| created_at | DATETIME2(3) DEFAULT SYSUTCDATETIME() |
| edited_at | DATETIME2(3) NULL |

Index: `(conversation_id, created_at DESC, id DESC)` for keyset pagination.

### 4.4 chat.MessageMedia

Similar to post media.

### 4.5 chat.MessageReceipts

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| message_id | BIGINT REFERENCES chat.Messages(id) ON DELETE CASCADE |
| user_id | BIGINT REFERENCES auth.Users(id) |
| receipt_type | TINYINT NOT NULL (0:delivered,1:read) |
| created_at | DATETIME2(3) |

Unique: `(message_id, user_id, receipt_type)`.

## Chat Şeması Özeti

- **Conversation**: Grup veya bireysel sohbet; `is_group` varsayılan `false`, `created_by_user_id` `auth.Users` tablosuna `RESTRICT` ile bağlı.
- **ConversationMember**: Üyelik satırı; `role` varsayılan `participant` (0), `last_read_*` alanları okuma durumunu izler, `(conversation_id, user_id)` benzersiz indeksli.
- **Message**: Sohbet mesajı; `deleted_for_all` varsayılan `false`, `sender_user_id` `auth.Users` ile `RESTRICT` bağlı, zaman bazlı indeks `(conversation_id, created_at, id)` ile keyset sıralı.
- **MessageMedia**: Mesaj ekleri; zorunlu `url`, isteğe bağlı `width/height`, `message_id` üzerinde indeks.
- **MessageReceipt**: Teslim/okundu kaydı; enum tabanlı `receipt_type`, `(message_id, user_id, receipt_type)` benzersiz indeksli.
- Tüm zaman damgaları `SYSUTCDATETIME()` varsayılanıyla tutulur; şema `chat` altında, ilişkiler EF konfigurasyonlarındaki `Cascade/Restrict` davranışlarıyla hizalı.

## 5. wallet schema

### 5.1 wallet.Accounts

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| user_id | BIGINT UNIQUE REFERENCES auth.Users(id) |
| balance | DECIMAL(18,2) NOT NULL DEFAULT 0 |
| currency | CHAR(3) NOT NULL DEFAULT 'CG' |
| updated_at | DATETIME2(3) DEFAULT SYSUTCDATETIME() |

### 5.2 wallet.Transactions

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| account_id | BIGINT REFERENCES wallet.Accounts(id) |
| external_id | UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID() UNIQUE |
| type | TINYINT NOT NULL (0:deposit,1:withdraw,2:transfer_out,3:transfer_in,4:purchase,5:refund) |
| amount | DECIMAL(18,2) NOT NULL |
| balance_after | DECIMAL(18,2) NOT NULL |
| reference | NVARCHAR(128) NULL |
| metadata | NVARCHAR(MAX) NULL |
| created_at | DATETIME2(3) DEFAULT SYSUTCDATETIME() |

Index on `(account_id, created_at DESC)`.

### 5.3 wallet.TransferAudits

Stores results of `wallet.sp_Transfer` (log from stored procedure).

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| from_account_id | BIGINT |
| to_account_id | BIGINT |
| amount | DECIMAL(18,2) |
| status | TINYINT | NOT NULL |
| created_at | DATETIME2(3) |

### 5.4 wallet.InAppPurchases

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| account_id | BIGINT REFERENCES wallet.Accounts(id) |
| platform | NVARCHAR(32) NOT NULL |
| receipt | NVARCHAR(MAX) NOT NULL |
| status | TINYINT NOT NULL (0:pending,1:validated,2:rejected) |
| created_at | DATETIME2(3) |
| validated_at | DATETIME2(3) NULL |

## 6. commerce schema

### 6.1 commerce.Vendors

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| public_id | UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID() UNIQUE |
| owner_user_id | BIGINT REFERENCES auth.Users(id) |
| name | NVARCHAR(128) NOT NULL |
| description | NVARCHAR(512) NULL |
| is_active | BIT NOT NULL DEFAULT 1 |
| created_at | DATETIME2(3) |
| updated_at | DATETIME2(3) |

### 6.2 commerce.Products

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| public_id | UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID() UNIQUE |
| vendor_id | BIGINT REFERENCES commerce.Vendors(id) ON DELETE CASCADE |
| title | NVARCHAR(256) NOT NULL |
| description | NVARCHAR(1024) NULL |
| price_cg | DECIMAL(18,2) NOT NULL |
| stock | INT NOT NULL |
| media_json | NVARCHAR(MAX) NULL (list of media items) |
| created_at | DATETIME2(3) |
| updated_at | DATETIME2(3) |

Index on `(vendor_id, title)`.

### 6.3 commerce.Orders

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| public_id | UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID() UNIQUE |
| buyer_user_id | BIGINT REFERENCES auth.Users(id) |
| vendor_id | BIGINT REFERENCES commerce.Vendors(id) |
| total_amount | DECIMAL(18,2) NOT NULL |
| status | TINYINT NOT NULL (0:pending,1:paid,2:shipped,3:released,4:refunded,5:canceled) |
| escrow_amount | DECIMAL(18,2) NOT NULL |
| created_at | DATETIME2(3) |
| updated_at | DATETIME2(3) |

### 6.4 commerce.OrderItems

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| order_id | BIGINT REFERENCES commerce.Orders(id) ON DELETE CASCADE |
| product_id | BIGINT REFERENCES commerce.Products(id) |
| product_public_id | UNIQUEIDENTIFIER NOT NULL |
| title | NVARCHAR(256) NOT NULL |
| unit_price | DECIMAL(18,2) NOT NULL |
| quantity | INT NOT NULL |
| created_at | DATETIME2(3) |

### 6.5 commerce.Escrows

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| order_id | BIGINT REFERENCES commerce.Orders(id) UNIQUE |
| hold_amount | DECIMAL(18,2) NOT NULL |
| status | TINYINT NOT NULL (0:on_hold,1:released,2:refunded) |
| created_at | DATETIME2(3) |
| updated_at | DATETIME2(3) |
| released_at | DATETIME2(3) NULL |
| refunded_at | DATETIME2(3) NULL |

## 7. moderation schema

### 7.1 moderation.Reports

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| reporter_user_id | BIGINT REFERENCES auth.Users(id) |
| target_type | TINYINT NOT NULL |
| target_id | NVARCHAR(64) NOT NULL |
| reason | TINYINT NOT NULL |
| detail | NVARCHAR(1024) NULL |
| status | TINYINT NOT NULL DEFAULT 0 (0:open,1:reviewing,2:resolved) |
| assigned_admin_user_id | BIGINT NULL REFERENCES auth.Users(id) |
| created_at | DATETIME2(3) |
| updated_at | DATETIME2(3) |
| resolved_at | DATETIME2(3) NULL |

### 7.2 moderation.Actions

Audit of moderation decisions.

### 7.3 moderation.VerificationRequests

Handles "mor tik" requests.

## 8. notify schema

### 8.1 notify.Notifications

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| user_id | BIGINT REFERENCES auth.Users(id) |
| type | TINYINT NOT NULL |
| payload | NVARCHAR(MAX) NOT NULL |
| is_read | BIT NOT NULL DEFAULT 0 |
| created_at | DATETIME2(3) |
| read_at | DATETIME2(3) NULL |

Index `(user_id, created_at DESC)`.

### 8.2 notify.Outbox

For guaranteed delivery.

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| topic | NVARCHAR(128) NOT NULL |
| payload | NVARCHAR(MAX) NOT NULL |
| status | TINYINT NOT NULL (0:pending,1:sent,2:failed) |
| retries | INT NOT NULL DEFAULT 0 |
| created_at | DATETIME2(3) |
| processed_at | DATETIME2(3) NULL |

### 8.3 outbox.Events

| Column | Type | Constraints |
| --- | --- | --- |
| id | BIGINT IDENTITY | PRIMARY KEY |
| topic | NVARCHAR(128) | NOT NULL |
| payload | NVARCHAR(MAX) | NOT NULL |
| status | TINYINT | NOT NULL DEFAULT 0 (0:pending,1:sent,2:failed) |
| retries | INT | NOT NULL DEFAULT 0 |
| created_at | DATETIME2(3) | NOT NULL DEFAULT SYSUTCDATETIME() |
| processed_at | DATETIME2(3) | NULL |

Indexler: `IX_OutboxEvents_Status` ve `IX_OutboxEvents_Status_CreatedAt`. Bu tablo, domain eventlerinin garantili teslimi icin global outbox katmani olarak kullanilir; Application katmanindaki `IOutboxEventWriter` servisi tarafindan doldurulur.

## 9. admin schema

Stores administrative metadata: categories, assignments, audit logs.

### 9.1 admin.Categories

| Column | Type |
| id | BIGINT IDENTITY PRIMARY KEY |
| name | NVARCHAR(128) UNIQUE |
| description | NVARCHAR(512) NULL |
| created_at | DATETIME2(3) |
| created_by_user_id | BIGINT REFERENCES auth.Users(id) |

### 9.2 admin.CategoryAdmins

Mapping of category to admin user.

### 9.3 admin.AuditLog

Generic log table capturing admin operations.

## 10. syscfg schema

| Table | Purpose |
| --- | --- |
| syscfg.FeatureFlags | Feature toggles (name, is_enabled, description, last_changed_at) |
| syscfg.AppSettings | Key-value store for misc configs |

## 11. Supporting objects

### 11.1 Stored Procedures

- `wallet.sp_Transfer` — atomic transfer, returns status + balances.
- `commerce.sp_EscrowRelease(order_id)` — moves escrow to vendor account.
- `commerce.sp_EscrowRefund(order_id)` — refunds to buyer.

### 11.2 Views

- `social.vw_FeedHome` — optional precomputed feed (user_id -> posts with joined aggregates).
- `chat.vw_ConversationPreviews` — for conversation listing.

### 11.3 Triggers

- Update `social.Posts.likes_count/comments_count` when likes/comments inserted (or handle via computed queries to avoid triggers).
- Maintain `wallet.Accounts.balance` in sync with transactions via stored procedure.

## 12. Next steps

1. Validate schema with product requirements, adjust column names and enumerations.
2. Define enumerations in Domain layer mirroring TINYINT codes.
3. Create ER diagram to visualize relationships.
4. Begin EF Core entity configuration classes reflecting this schema.
5. Draft initial migration (`Init`).

---

Feedback welcome—once approved, we can proceed to ERD + EF Core model generation.
