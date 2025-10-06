const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'cringe-bank' });
const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

async function create() {
  try {
    await db.collection('config').doc('allowedMediaHosts').set({
      hosts: [
        'imgur.com',
        'i.imgur.com', 
        'youtube.com',
        'youtu.be',
        'i.ytimg.com',
        'giphy.com',
        'media.giphy.com',
        'tenor.com',
        'media.tenor.com',
        'unsplash.com',
        'images.unsplash.com'
      ],
      description: 'Allowed domains for external media URLs in direct messages',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: 'system'
    });
    console.log(' Created!');
  } catch (e) {
    console.log(' Error:', e.message);
  }
  process.exit(0);
}
create();
