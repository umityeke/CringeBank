# Firestore & Storage Security Contract


## Scope and Intent

This contract translates the security, moderation, and data-shaping requirements for the Cringe Bankası platform into actionable guidance for whoever authors the Firestore and Cloud Storage rules. Treat it as the canonical reference when building or auditing rules and any supporting Cloud Functions. The document intentionally avoids code; instead it defines the expectations your implementation **must** satisfy.


## Identity & Roles

- **Authentication baseline**: Any write (create, update, delete) in Firestore or Storage requires a signed-in Firebase Auth user (`request.auth != null`).
- **Roles**:
  - **Normal user**: No special claims. Can create their own content and edit limited fields on it.
  - **Moderator**: Custom claim `moderator == true`. Can view and edit moderated content, resolve reports, and override statuses.
- **Ownership**: Documents expose an `ownerId` field. Only the owner or a moderator may modify or delete that document unless noted otherwise.


## Status Vocabulary

`status` fields across posts, comments, and media accept only: `pending`, `approved`, `rejected`, `blocked`.

- Default on creation: `pending`.
- Visibility:
  - `approved`: public.
  - `pending` or `rejected`: visible to the owner and moderators only.
  - `blocked`: moderators only (owner denied).
- Moderators manage final disposition and may record decisions in a `moderation` map that stores reasons, automation scores, etc.


## Timestamp Conventions

- `createdAt`: Required on creation, server timestamp in **milliseconds**.
- `updatedAt`: Optional; updated when the document changes.
- Clients should use Cloud Functions or server timestamps to prevent spoofing.


## Collection Contracts


### 1. `posts/{postId}`

**Purpose**: Primary user submissions. Types: `spill`, `clap`, `frame`, `cringecast`, `mash`.

**Required fields on create**:

- `ownerId` = `request.auth.uid`.
- `type` ∈ {`spill`, `clap`, `frame`, `cringecast`, `mash`}.
- `status` = `pending`.
- `createdAt` (ms epoch).
- `text`: required or optional according to post type (see below).
- `media`: optional list of Storage paths. Every entry must match `user_uploads/{ownerId}/{postId}/...`.
- `moderation`: optional map written only by moderators or back-end automation.

**Read access**:

- Any user may read `approved` posts.
- `pending` / `rejected`: owner + moderators.
- `blocked`: moderators only (owner denied).

**Create**:

- Authenticated users only.
- Validate `ownerId`, `status`, `type`, `createdAt` as described.
- Enforce post-type payload limits (text length, media count).
- Ensure every `media` path belongs to the owner and references the same `postId`.

**Update**:

- Owner can update only `text`, `media`, `updatedAt`.
- Owner cannot alter `ownerId`, `type`, `createdAt`, `status`, or `moderation`.
- Moderators can update any field, including `status` and `moderation`.

**Delete**:

- Owner or moderator may remove the post.

**Type-specific constraints**:

- `spill`: text required (length 1–2000), media optional (0–1 item).
- `clap`: text required (length 1–140), media optional (0–1 item).
- `frame`: media required (≥1 asset), text optional (≤1000 chars).
- `cringecast`: media required (exactly 1 video), text optional (≤1000 chars).
- `mash`: media required (1–5 assets), text optional (≤2000 chars).


### 2. `posts/{postId}/comments/{commentId}`

**Required fields**:

- `ownerId` = `request.auth.uid` (on create).
- `text` length 1–2000.
- `status` = `pending` on create.
- `createdAt` (ms epoch); optional `updatedAt`.
- `moderation`: optional, moderator/automation only.

**Read**:

- Mirrors post visibility: `approved` public; other statuses restricted to owner + moderators, `blocked` moderators only if you adopt that state here.

**Create**:

- Signed-in users only.
- Enforce text length, ownership, default status, timestamps.

**Update**:

- Owner: may edit `text` and `updatedAt` only.
- Moderators: may edit any field, including `status` and `moderation`.

**Delete**:

- Owner or moderator.


### 3. `reports/{reportId}`

**Purpose**: User-generated moderation tickets.

**Required fields**:

- `reporterId` = `request.auth.uid`.
- `target`: map with `type` ∈ {`post`, `comment`, `user`} and `id` (string identifier).
- `reason` ∈ {`nudity`, `harassment`, `spam`, `hate`, `violence`, `other`}.
- Optional `note` ≤1000 chars.
- `createdAt` (ms epoch).
- `status`: defaults to `open` on creation.

**Read**:

- Reporter can access their own reports.
- Moderators can read all reports.

**Write**:

- Create: authenticated users.
- Update/Delete: moderators only (used to change `status`, add moderation notes, or close a report).


### 4. `users/{uid}`

**Read**:

- Public profile fields may be readable by everyone (adjust if you need privacy controls).

**Update**:

- Owner may update allowed profile fields (e.g., `displayName`, `bio`, `avatar`).
- Moderators may update or annotate moderation-related fields.
- Nobody except trusted back-end logic/moderators may modify: `role`, `claims`, `isBanned`, `moderation`, or any fields storing custom claims / enforcement data.


## Cloud Storage Contract

**Path schema**: `user_uploads/{uid}/{postId}/{fileName}`.

**Metadata**:

- Required meta keys on upload: `postId` (string) and `status` (`pending` initially).
- Back-end moderation updates `status` to `approved`, `rejected`, or `blocked` alongside Firestore.

**Read**:

- Anyone may read files whose metadata `status == 'approved'`.
- Owner (`uid`) and moderators may read files in other statuses.

**Write / Upload**:

- Only the owner may upload into their folder (`request.auth.uid == uid`).
- Enforce maximum file size 25 MB.
- Restrict `contentType` to `image/*` or `video/*`.
- Validate supplied metadata (`postId` ties back to Firestore document and matches path segment).

**Delete**:

- Owner can delete their own files.
- Moderators can delete any file (e.g., removing blocked content).

**Media type expectations**:

- Front-end/back-end should ensure images use formats like JPG/PNG/WebP; videos MP4/WebM.
- Derived assets (thumbnails, transcripts) live under the same `postId` folder and follow the same metadata contract.


## Moderation Workflow Alignment

1. User submits post/comment → Firestore `status = pending`, Storage metadata `status = pending`.
2. Automated checks (Cloud Functions) evaluate text/media (Perspective API, Vision, etc.) and populate the `moderation` map.
3. Moderators review dashboards fed by pending items:
   - Approve → set `status = approved` in Firestore and Storage metadata.
   - Reject → set `status = rejected`, optionally retain owner visibility.
   - Block → set `status = blocked`; owner loses access in Firestore and Storage.
4. Client displays only what it can read per rules.


## Client Responsibilities

- Always write server timestamps and default statuses correctly.
- Enforce text length and media count constraints before writing.
- Upload media prior to storing Firestore document references and respect the path schema.
- When editing, restrict to allowed fields (text/media/updatedAt) and let moderators handle status transitions.
- Provide reporting UI that writes to `reports` with the defined payload, and show report history only to the reporter.


## Rate Limiting & Abuse Controls

- Firestore rules cannot throttle usage. Implement rate caps in Cloud Functions (e.g., callable function that checks "posts created in last X minutes" before allowing another publish).
- Consider routing all post/comment creation through a function so the server validates quotas before writing to Firestore.
- Honor a `users/{uid}.isBanned` (or similar) flag server-side; rules can deny writes when this flag is true.
- Track moderation and automation signals in `moderation` maps to support future blocking heuristics.


## Implementation Checklist

- [ ] Firestore rules enforce authentication for all writes.
- [ ] Role detection via custom claims (`moderator`).
- [ ] Per-collection field validation and ownership checks implemented exactly as described.
- [ ] Status-based read filters applied consistently to posts and comments.
- [ ] Cloud Storage rules mirror visibility logic and metadata constraints.
- [ ] Cloud Functions (or equivalent) update both Firestore and Storage metadata during moderation.
- [ ] Client-side forms respect length/media limits and default statuses.
- [ ] Reporting workflow built with restricted visibility.


Adhering to this contract ensures moderation decisions propagate everywhere, sensitive content remains private until approved, and only authorized actors can alter critical fields.
