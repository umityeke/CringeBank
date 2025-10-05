# CringeBank Security Contract

## 📋 Overview

This document defines the **complete security architecture** for CringeBank's Firestore and Storage systems. All rules are implemented in:
- `firestore.rules` - Database security
- `storage.rules` - File storage security

---

## 🔐 Core Security Principles

### 1. Authentication
- **Requirement**: Only authenticated users (Firebase Auth) can write data
- **Public Read**: Some approved content is publicly readable
- **Private Read**: Pending/rejected/blocked content has restricted access

### 2. Roles
- **User**: Normal authenticated user
- **Moderator**: User with custom claim `moderator: true`

### 3. Ownership
- Users can only create/modify their own content (identified by `ownerId`)
- Moderators can modify any content

### 4. Moderation States
All content has a `status` field with these values:

| Status | Description | Visibility |
|--------|-------------|------------|
| `pending` | User created; awaiting moderation | Owner + Moderator |
| `approved` | Moderator approved; public content | Everyone |
| `rejected` | Moderator rejected; flagged content | Owner + Moderator |
| `blocked` | Rule violation; hidden from owner | Moderator only |

---

## 📊 Collection Structure

### 1. `/posts/{postId}`

**Purpose**: User-generated content in 5 types: spill, clap, frame, cringecast, mash

#### Required Fields
- `ownerId` (string): Must equal `request.auth.uid`
- `type` (string): One of: `spill`, `clap`, `frame`, `cringecast`, `mash`
- `status` (string): Must be `pending` on creation
- `createdAt` (int): Timestamp in milliseconds
- `text` (string): Content text (type-dependent requirements)
- `media` (list<string>): Storage paths (type-dependent requirements)
- `moderation` (map, optional): Only moderator/backend can write

#### Type-Specific Rules

| Type | Text Required | Text Limit | Media Required | Media Limit |
|------|--------------|------------|----------------|-------------|
| **spill** | ✅ Yes | 1-2000 chars | ❌ No | 0-1 files |
| **clap** | ✅ Yes | 1-140 chars | ❌ No | 0-1 files |
| **frame** | ❌ Optional | ≤1000 chars | ✅ Yes | 1-20 images |
| **cringecast** | ❌ Optional | ≤1000 chars | ✅ Yes | Exactly 1 video |
| **mash** | ❌ Optional | ≤2000 chars | ✅ Yes | 1-5 files |

#### Permissions

**Read**
```javascript
status == 'approved' → Everyone
status == 'pending' || 'rejected' → Owner OR Moderator
status == 'blocked' → Moderator only
```

**Create**
- Any signed-in user
- `ownerId` must equal `request.auth.uid`
- `status` must be `pending`
- Type rules must be satisfied
- Cannot set `moderation` field

**Update**
- **Owner**: Can modify `text`, `media`, `updatedAt` only
- **Owner**: Cannot change `ownerId`, `type`, `createdAt`, `status`, `moderation`
- **Moderator**: Can change anything including `status` and `moderation`

**Delete**
- Owner OR Moderator

---

### 2. `/posts/{postId}/comments/{commentId}`

**Purpose**: Comments on posts

#### Required Fields
- `ownerId` (string): Must equal `request.auth.uid`
- `text` (string): 1-2000 characters
- `status` (string): Must be `pending` on creation
- `createdAt` (int): Timestamp in milliseconds
- `updatedAt` (int, optional): Update timestamp
- `moderation` (map, optional): Moderator-only field

#### Permissions

**Read**: Same as posts (based on `status`)

**Create**
- Any signed-in user
- `status` must be `pending`
- Cannot set `moderation` field

**Update**
- **Owner**: Can modify `text`, `updatedAt` only
- **Moderator**: Can change `status`, `moderation`, and other fields

**Delete**: Owner OR Moderator

---

### 3. `/reports/{reportId}`

**Purpose**: User reports for content violations

#### Required Fields
- `reporterId` (string): Must equal `request.auth.uid`
- `target` (map): 
  - `type` (string): `post`, `comment`, or `user`
  - `id` (string): Target document ID
- `reason` (string): One of: `nudity`, `harassment`, `spam`, `hate`, `violence`, `other`
- `note` (string, optional): Max 1000 characters
- `status` (string): Must be `open` on creation
- `createdAt` (int): Timestamp in milliseconds

#### Permissions

**Read**
- Reporter (own reports)
- Moderator (all reports)

**Create**
- Any signed-in user
- `reporterId` must equal `request.auth.uid`
- `status` must be `open`

**Update**
- Moderator only
- Cannot change `reporterId`, `target`, `reason`, `createdAt`
- Can change `status` (e.g., to `investigating`, `resolved`, `dismissed`)

**Delete**: Moderator only

---

### 4. `/users/{userId}`

**Purpose**: User profiles

#### Protected Fields
These fields **cannot be modified by users**, only by moderators or system:
- `role`
- `claims`
- `isBanned`
- `moderation`

#### Permissions

**Read**: Public (everyone can read user profiles)

**Create**: User can create own profile (`userId == request.auth.uid`)

**Update**
- **User**: Can update own profile except protected fields
- **Moderator**: Can update everything including protected fields

**Delete**: No one (user accounts persist)

---

## 💾 Storage Security

### Path Structure
```
user_uploads/{uid}/{postId}/{fileName}
```

### Required Metadata
Every uploaded file must have:
- `postId`: Matches the `{postId}` in the path
- `status`: Initially `pending`, updated by moderation system

### File Constraints
- **Content Type**: `image/*` or `video/*` only
- **Max Size**: 25 MB
- **Path Ownership**: `{uid}` must match uploader's `request.auth.uid`

### Permissions

**Read**
```javascript
metadata.status == 'approved' → Everyone
metadata.status == 'pending' || 'rejected' → Owner OR Moderator
metadata.status == 'blocked' → Moderator only
```

**Create**
- Only owner can upload to `user_uploads/{uid}/`
- Must set `metadata.postId` and `metadata.status = 'pending'`
- Content type and size must be valid

**Update**
- Owner can update metadata (status must remain `pending`)
- Moderator can update to any valid status

**Delete**: Owner OR Moderator

---

## 🔄 Moderation Workflow

### 1. Content Creation
```
User creates post/comment → status: pending
User uploads media → metadata.status: pending
```

### 2. Backend Processing (Cloud Functions)
```javascript
// Firestore trigger on posts/{postId} creation
exports.moderatePost = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    // Text moderation (Perspective API, profanity filters)
    const textScore = await analyzeText(data.text);
    
    // Media moderation (Vision AI, Video AI)
    const mediaScores = await analyzeMedia(data.media);
    
    // Decision logic
    let newStatus = 'approved';
    let moderationData = { scores: { text: textScore, media: mediaScores } };
    
    if (textScore.toxicity > 0.8 || mediaScores.nsfw > 0.9) {
      newStatus = 'blocked';
      moderationData.reason = 'Auto-flagged: High toxicity/NSFW';
    } else if (textScore.toxicity > 0.5) {
      newStatus = 'pending'; // Keep for manual review
      moderationData.flagged = true;
    }
    
    // Update Firestore
    await snap.ref.update({ status: newStatus, moderation: moderationData });
    
    // Update Storage metadata
    for (const mediaPath of data.media || []) {
      await updateStorageMetadata(mediaPath, { status: newStatus });
    }
  });
```

### 3. Display Logic (Client)
```dart
// Only show approved content in public feeds
Stream<List<Post>> getPublicFeed() {
  return firestore
    .collection('posts')
    .where('status', isEqualTo: 'approved')
    .orderBy('createdAt', descending: true)
    .snapshots();
}

// Show pending/rejected in user's own profile
Stream<List<Post>> getUserPosts(String userId) {
  return firestore
    .collection('posts')
    .where('ownerId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
    .snapshots();
}
```

---

## 🛡️ Rate Limiting & Abuse Prevention

### Recommendations

1. **Firestore Rules** don't support rate limiting directly
2. **Implement via Cloud Functions**:
   ```javascript
   // Callable function for creating posts
   exports.createPost = functions.https.onCall(async (data, context) => {
     const uid = context.auth.uid;
     
     // Check user ban status
     const user = await firestore.collection('users').doc(uid).get();
     if (user.data().isBanned) {
       throw new functions.https.HttpsError('permission-denied', 'User is banned');
     }
     
     // Rate limit: Max 10 posts in last 60 minutes
     const recentPosts = await firestore
       .collection('posts')
       .where('ownerId', '==', uid)
       .where('createdAt', '>', Date.now() - 3600000)
       .get();
     
     if (recentPosts.size >= 10) {
       throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded');
     }
     
     // Create post
     return firestore.collection('posts').add({
       ...data,
       ownerId: uid,
       status: 'pending',
       createdAt: admin.firestore.FieldValue.serverTimestamp()
     });
   });
   ```

3. **Client enforces calling the Cloud Function** instead of direct Firestore writes

---

## 🚀 Deployment

### Deploy Rules to Firebase
```powershell
# From project root
firebase deploy --only firestore:rules,storage
```

### Validate Rules Locally
```powershell
# Test Firestore rules
firebase emulators:start --only firestore

# Test Storage rules
firebase emulators:start --only storage
```

### CI/CD Integration
```yaml
# .github/workflows/deploy-rules.yml
name: Deploy Security Rules
on:
  push:
    branches: [main]
    paths:
      - 'firestore.rules'
      - 'storage.rules'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: w9jds/firebase-action@master
        with:
          args: deploy --only firestore:rules,storage
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

---

## ✅ Security Checklist

- [x] Authentication required for all writes
- [x] Ownership validation on creation
- [x] Protected fields (status, moderation, role) enforced
- [x] Type-specific content validation (spill, clap, frame, etc.)
- [x] Moderator-only status changes
- [x] Media path validation (owner's folder only)
- [x] File size limits (25 MB max)
- [x] Content type restrictions (image/video only)
- [x] Status-based read access control
- [x] Reports accessible only to reporter/moderator
- [x] User profile protected fields
- [x] Default deny-all rule for unknown paths

---

## 📚 Additional Resources

- [Firestore Security Rules Reference](https://firebase.google.com/docs/firestore/security/rules-structure)
- [Storage Security Rules Reference](https://firebase.google.com/docs/storage/security)
- [Custom Claims Documentation](https://firebase.google.com/docs/auth/admin/custom-claims)
- [Content Moderation Best Practices](https://cloud.google.com/blog/products/ai-machine-learning/google-cloud-ai-content-moderation)

---

**Last Updated**: October 5, 2025  
**Version**: 2.0 - Enterprise Security Contract  
**Status**: ✅ Production Ready
