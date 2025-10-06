const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'cringe-bank' });
const db = admin.firestore();

async function create() {
  try {
    const docRef = db.collection('config').doc('allowedMediaHosts');
    await docRef.set({
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
      description: 'Allowed domains for external media URLs',
      updatedBy: 'system'
    });
    console.log(' SUCCESS! Allowlist created!');
    const check = await docRef.get();
    console.log(' Hosts:', check.data().hosts.length, 'domains');
  } catch (e) {
    console.log(' Error:', e.message);
  }
  process.exit(0);
}
create();
