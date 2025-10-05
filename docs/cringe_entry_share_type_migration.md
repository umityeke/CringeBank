# Cringe Entry Share Type Migration Guide

This note captures the recommended steps for moving existing cringe entry data
and media assets from the legacy category-only structure into the new
`cringe_entries_by_type/{shareType}/categories/{category}/entries/{entryId}`
layout introduced in March 2025.

## 1. Preparation

1. **Enable backups** – Run a Firestore export (or take a backup copy of the
   `cringe_entries_by_category` subtree) before mutating any data.
2. **Freeze writes** – Temporarily disable in-app entry creation while the
   migration runs to avoid drift between the legacy and new locations.
3. **Update rules** – Deploy the updated `firestore.rules` that allow access to
   both the new share-type structure and the legacy paths during the migration
   window.

## 2. Firestore document migration

You can execute the migration as a one-off Node.js script using the existing
`functions` package setup. The high-level algorithm is:

1. Iterate over every document in
   `cringe_entries_by_category/{category}/entries/{entryId}`.
2. Determine the share type with the same helper the client now uses:
   - `videoUrl` present → `video`
   - `audioUrl` present → `audio`
   - `imageUrls` non-empty → `image`
   - More than one medium → `mixed`
   - Otherwise → `text`
3. Build the destination reference:
   `cringe_entries_by_type/{shareType}/categories/{categoryKey}/entries/{entryId}`.
4. Copy the document data, ensuring the new `shareType`, `categoryKey`, and
   `username`/`userId` fields are populated. Preserve `createdAt` timestamps by
   writing them explicitly (do not rely on server timestamps during migration).
5. Copy every comment in the document's `comments` subcollection to the new
   location. A `WriteBatch` sized at ~100 writes keeps throughput healthy.
6. After the data copy completes, delete the legacy document to prevent double
   counting. Perform deletions in a separate batch to avoid exceeding batch
   limits.

> **Tip**: For very large datasets, process in parallel per category to avoid
> long-running transactions. Track progress with a resume token or record the
> last processed document ID in case the script needs to restart.

## 3. Firebase Storage migration

Uploaded media now resides under
`cringe_entries/{shareType}/{category}/{userId}/...`. To migrate existing media:

1. List all objects beneath `cringe_entries/{category}/`.
2. For each object, identify the owning entry and infer its share type using the
   same logic as above.
3. Copy the object into
   `cringe_entries/{shareType}/{category}/{userId}/{originalFilename}`.
4. Update the Firestore entry's `imageUrls` (or `videoUrl`/`audioUrl`) to point
   at the new download URLs if the path changed.
5. After verifying integrity, delete the legacy object.

If you are using the Firebase Admin SDK, the `bucket.file(oldPath).copy(newPath)`
API preserves metadata while writing to the new location.

## 4. Validation checklist

- [ ] Spot check a handful of entries per share type in the app.
- [ ] Confirm comments continue to load from the new path for migrated entries.
- [ ] Ensure analytics dashboards or scheduled exports reference the new
      collection hierarchy.
- [ ] Remove the legacy security rule block once all documents are migrated.
- [ ] Re-enable entry creation in the client.

## 5. Rollback plan

Because documents are copied before deletion, you can recover by restoring the
backup or by copying data back from the new path to the legacy path using the
same script (swap source/destination). Keep the legacy rules in place until the
migration is fully verified.
