const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');
const { v4: uuidv4 } = require('uuid');
const fetch = require('node-fetch');
const { GoogleAuth } = require('google-auth-library');

// Initialize Firebase Admin with service account
const serviceAccount = require('../tiktok/tiktok-2c2fa-firebase-adminsdk-fbsvc-6e0aafe71b.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'tiktok-2c2fa.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Keep track of created resources for cleanup
const createdResources = {
  videoIds: [],
  storagePaths: [],
  localFiles: []
};

// Sample video URLs (replace these with actual royalty-free video URLs)
const sampleVideos = [
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4'
];

async function downloadVideo(url, localPath) {
  console.log(`\n📥 Downloading video from ${url}`);
  console.log(`   To: ${localPath}`);
  
  return new Promise((resolve, reject) => {
    https.get(url, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download video: ${response.statusCode} ${response.statusMessage}`));
        return;
      }

      const fileStream = fs.createWriteStream(localPath);
      response.pipe(fileStream);
      
      fileStream.on('finish', () => {
        fileStream.close();
        const fileSizeInMB = fs.statSync(localPath).size / (1024 * 1024);
        console.log(`   ✅ Download complete (${fileSizeInMB.toFixed(2)} MB)`);
        resolve();
      });

      fileStream.on('error', (error) => {
        fs.unlinkSync(localPath);
        reject(error);
      });
    }).on('error', reject);
  });
}

async function uploadVideo(localPath, storagePath) {
  console.log(`\n⬆️ Uploading video to Firebase Storage`);
  console.log(`   From: ${localPath}`);
  console.log(`   To: ${storagePath}`);

  await bucket.upload(localPath, {
    destination: storagePath,
    metadata: {
      contentType: 'video/mp4'
    }
  });

  const [signedUrl] = await bucket.file(storagePath).getSignedUrl({
    action: 'read',
    expires: Date.now() + 7 * 24 * 60 * 60 * 1000 // 7 days
  });

  console.log('   ✅ Upload complete');
  console.log(`   📎 Signed URL: ${signedUrl}`);
  return signedUrl;
}

async function getIdentityToken() {
  const auth = new GoogleAuth({
    keyFilename: '../tiktok/tiktok-2c2fa-firebase-adminsdk-fbsvc-6e0aafe71b.json',
    
  });

  const client = await auth.getIdTokenClient(
    'https://us-central1-tiktok-2c2fa.cloudfunctions.net/convertVideoToHLS'
  );

  // Fetch a valid Identity Token
  const identityToken = await client.idTokenProvider.fetchIdToken(
    'https://us-central1-tiktok-2c2fa.cloudfunctions.net/convertVideoToHLS'
  );

  return identityToken; // Correct return type
}

async function convertToHLS(filePath) {
  console.log(`\n🎬 Converting video to HLS: ${filePath}`);
  
  // Get the metadata token for authentication
  const metadataToken = await getIdentityToken();
  console.log(`   🔑 Metadata token: ${metadataToken}`);
  const projectId = "tiktok-2c2fa";
  const region = 'us-central1'; // Change this if your function is in a different region
  const functionName = 'convertVideoToHLS';
  
  // Call the function using the service account token
  const url = `https://${region}-${projectId}.cloudfunctions.net/${functionName}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${metadataToken}`
    },
    body: JSON.stringify({ filePath }) 
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to convert video: ${error}`);
  }

  const result = await response.json();
  console.log('   ✅ Conversion successful');
  console.log(`   📎 HLS URL: ${result.hlsURL}`);
  return {
    hlsURL: result.hlsURL,
    hlsPath: result.hlsPath
  };
}

async function cleanup() {
  console.log('\n🧹 Starting cleanup...');
  
  // Delete local files
  for (const localFile of createdResources.localFiles) {
    try {
      if (fs.existsSync(localFile)) {
        fs.unlinkSync(localFile);
        console.log(`   ✅ Deleted local file: ${localFile}`);
      }
    } catch (error) {
      console.error(`   ❌ Failed to delete local file ${localFile}:`, error);
    }
  }

  // Delete storage files
  for (const storagePath of createdResources.storagePaths) {
    try {
      await bucket.file(storagePath).delete();
      console.log(`   ✅ Deleted storage file: ${storagePath}`);
    } catch (error) {
      console.error(`   ❌ Failed to delete storage path ${storagePath}:`, error);
    }
  }

  // Delete Firestore documents
  for (const videoId of createdResources.videoIds) {
    try {
      await db.collection('videos').doc(videoId).delete();
      console.log(`   ✅ Deleted Firestore document: ${videoId}`);
    } catch (error) {
      console.error(`   ❌ Failed to delete Firestore document ${videoId}:`, error);
    }
  }

  console.log('🏁 Cleanup completed');
}

async function generateTestVideos(count = 20) {
  console.log(`\n🎬 Starting test video generation (count: ${count})`);
  console.log('================================================');
  
  try {
    // Check if bucket exists
    const [exists] = await bucket.exists();
    if (!exists) {
      throw new Error(`Bucket ${bucket.name} does not exist. Please create it in the Firebase Console.`);
    }
    console.log(`\n📦 Using bucket: ${bucket.name}`);

    const tempDir = path.join(__dirname, 'temp');
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir);
      console.log(`\n📁 Created temp directory: ${tempDir}`);
    }

    for (let i = 0; i < count; i++) {
      try {
        console.log(`\n📽️ Processing video ${i + 1}/${count}`);
        console.log('------------------------');
        
        const videoId = uuidv4();
        createdResources.videoIds.push(videoId);
        
        const sampleVideo = sampleVideos[i % sampleVideos.length];
        const localPath = path.join(tempDir, `${videoId}.mp4`);
        createdResources.localFiles.push(localPath);
        
        const storagePath = `videos/original/${videoId}.mp4`;
        createdResources.storagePaths.push(storagePath);
        
        // Download sample video
        await downloadVideo(sampleVideo, localPath);

        // Upload to Firebase Storage
        const originalUrl = await uploadVideo(localPath, storagePath);

        // Create Firestore document
        console.log('\n📝 Creating Firestore document');
        await db.collection('videos').doc(videoId).set({
          originalPath: storagePath,
          originalUrl: originalUrl,
          status: 'processing',
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('   ✅ Created Firestore document');

        // Convert video to HLS
        const result = await convertToHLS(storagePath);
        
        // Update document with HLS URL
        await db.collection('videos').doc(videoId).update({
          status: 'completed',
          hlsPath: `${result.hlsPath}/output.m3u8`,
          hlsUrl: result.hlsURL,
          type: 'hls'
        });
        console.log('   ✅ Updated document with HLS URL');

        // Clean up local file
        fs.unlinkSync(localPath);
        const localFileIndex = createdResources.localFiles.indexOf(localPath);
        if (localFileIndex > -1) {
          createdResources.localFiles.splice(localFileIndex, 1);
        }
        console.log('\n🗑️ Cleaned up local file');

      } catch (error) {
        console.error('\n❌ Error processing video:', error);
        console.log('\n⚠️ Starting cleanup of created resources...');
        await cleanup();
        process.exit(1);
      }
    }

    // Clean up temp directory
    if (fs.existsSync(tempDir)) {
      fs.rmdirSync(tempDir);
      console.log('\n🗑️ Cleaned up temp directory');
    }

    console.log('\n✨ Successfully generated all test videos!');
    console.log(`   Created ${count} videos with HLS streams`);

  } catch (error) {
    console.error('\n💥 Fatal error:', error);
    console.log('\n⚠️ Starting cleanup of created resources...');
    await cleanup();
    process.exit(1);
  }
}

// Handle process termination
process.on('SIGINT', async () => {
  console.log('\n\n⚠️ Process interrupted. Starting cleanup...');
  await cleanup();
  process.exit(1);
});

// Run the script
generateTestVideos(20).catch(async (error) => {
  console.error('\n💥 Unhandled error:', error);
  await cleanup();
  process.exit(1);
});
