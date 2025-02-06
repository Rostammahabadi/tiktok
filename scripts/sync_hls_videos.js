const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin with service account
const serviceAccount = require('../tiktok/tiktok-2c2fa-firebase-adminsdk-fbsvc-6e0aafe71b.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'tiktok-2c2fa.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

async function syncHLSVideos() {
  console.log('\n🔄 Starting HLS video sync');
  console.log('========================');

  try {
    // List all files in the videos directory
    const [files] = await bucket.getFiles({
      prefix: 'videos/hls/'
    });

    console.log('\n📁 Found files:');
    files.forEach(file => {
      console.log(`   ${file.name}`);
    });

    // Group files by video ID (parent directory name)
    const videoGroups = new Map();
    files.forEach(file => {
      const match = file.name.match(/videos\/hls\/([^\/]+)\//);
      if (match) {
        const videoId = match[1];
        if (!videoGroups.has(videoId)) {
          videoGroups.set(videoId, []);
        }
        videoGroups.get(videoId).push(file);
      }
    });

    console.log(`\n📁 Found ${videoGroups.size} HLS video groups`);

    // Process each video group
    for (const [videoId, files] of videoGroups) {
      console.log(`\n🎬 Processing video: ${videoId}`);

      // Find the playlist file (output.m3u8)
      const playlistFile = files.find(f => f.name.endsWith('output.m3u8'));
      if (!playlistFile) {
        console.log(`   ⚠️ No playlist file found for ${videoId}, skipping`);
        continue;
      }

      // Check for original MP4 file in Firebase Storage
      const originalPath = `videos/original/${videoId}.mp4`;
      let originalExists = false;
      let originalSize = null;
      let originalLastModified = null;

      try {
        const [originalMetadata] = await bucket.file(originalPath).getMetadata();
        originalExists = true;
        originalSize = originalMetadata.size;
        originalLastModified = originalMetadata.updated;
        console.log(`   ✅ Found original file: ${originalPath} (${(originalSize / 1024 / 1024).toFixed(2)} MB)`);
      } catch (error) {
        // Try with uppercase ID for iOS-generated files
        const uppercasePath = `videos/original/${videoId.toUpperCase()}.mp4`;
        try {
          const [originalMetadata] = await bucket.file(uppercasePath).getMetadata();
          originalExists = true;
          originalPath = uppercasePath;
          originalSize = originalMetadata.size;
          originalLastModified = originalMetadata.updated;
          console.log(`   ✅ Found original file: ${originalPath} (${(originalSize / 1024 / 1024).toFixed(2)} MB)`);
        } catch (upperError) {
          console.log(`   ⚠️ Original file not found at ${originalPath} or ${uppercasePath}`);
        }
      }

      // Get signed URL for the playlist
      const [url] = await playlistFile.getSignedUrl({
        version: 'v4',
        action: 'read',
        expires: Date.now() + 7 * 24 * 60 * 60 * 1000 // 1 week
      });

      // Get signed URL for the original file if it exists
      let originalUrl = null;
      if (originalExists) {
        try {
          const [signedUrl] = await bucket.file(originalPath).getSignedUrl({
            version: 'v4',
            action: 'read',
            expires: Date.now() + 7 * 24 * 60 * 60 * 1000 // 1 week
          });
          originalUrl = signedUrl;
        } catch (error) {
          console.log(`   ⚠️ Error getting signed URL for original file: ${error.message}`);
        }
      }

      // Check if document exists
      const docRef = db.collection('videos').doc(videoId);
      const doc = await docRef.get();

      const videoData = {
        hlsUrl: url,
        hlsPath: playlistFile.name,
        status: 'completed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      if (originalExists) {
        videoData.originalPath = originalPath;
        videoData.originalUrl  = originalUrl;
        videoData.originalSize = originalSize;
        videoData.originalLastModified = originalLastModified;
      }

      if (doc.exists) {
        // Update existing document
        await docRef.update(videoData);
        console.log('   ✅ Updated existing document');
      } else {
        // Create new document
        await docRef.set({
          id: videoId,
          title: `Video ${videoId}`,
          description: 'Auto-synced HLS video',
          likes: 0,
          views: 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          ...videoData
        });
        console.log('   ✅ Created new document');
      }
    }

    console.log('\n✨ Successfully synced all HLS videos!');

  } catch (error) {
    console.error('\n💥 Error syncing HLS videos:', error);
    process.exit(1);
  }
}

// Run the sync
syncHLSVideos().then(() => {
  console.log('\n👋 Done!');
  process.exit(0);
}).catch(error => {
  console.error('\n💥 Fatal error:', error);
  process.exit(1);
});
