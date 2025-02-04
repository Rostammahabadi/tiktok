const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const {spawn} = require("child_process");
const path = require("path");
const os = require("os");
const fs = require("fs");

// If using ffmpeg-static, install it via "npm install ffmpeg-static" and require:
const ffmpegPath = require("ffmpeg-static");
// Alternatively, if you have a custom approach, set ffmpegPath to your own binary.

exports.convertVideoToHLS = functions
    .runWith({
      // Increase memory if needed for large files
      memory: "1GB",
      timeoutSeconds: 540, // 9 minutes, adjust as needed
    })
    .https.onCall(async (data, context) => {
      // data.filePath is the path in Firebase Storage of the MP4
      const filePath = data.filePath;
      if (!filePath) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "The function must be called with 'filePath'.",
        );
      }

      const bucket = admin.storage().bucket();
      const fileName = path.basename(filePath, ".mp4");
      const tempLocalFile = path.join(os.tmpdir(), fileName + ".mp4");
      const hlsOutputFolder = path.join(os.tmpdir(), fileName + "-hls");

      try {
        // 1) Download the MP4 to local temp storage
        await bucket.file(filePath).download({destination: tempLocalFile});
        console.log(`Downloaded video to ${tempLocalFile}`);

        // 2) Create a local folder for HLS output
        fs.mkdirSync(hlsOutputFolder, {recursive: true});

        // 3) Spawn ffmpeg to convert MP4 -> HLS
        //    Example basic command:
        //    ffmpeg -i input.mp4 -profile:v baseline -level 3.0 -start_number 0 \
        //           -hls_time 10 -hls_list_size 0 -f hls output.m3u8
        await new Promise((resolve, reject) => {
          const args = [
            "-i",
            tempLocalFile,
            "-profile:v",
            "baseline",
            "-level",
            "3.0",
            "-start_number",
            "0",
            "-hls_time",
            "6", // segment length in seconds
            "-hls_list_size",
            "0",
            "-f",
            "hls",
            path.join(hlsOutputFolder, "output.m3u8"),
          ];

          console.log(`Spawning ffmpeg with args: ${args.join(" ")}`);
          const ffmpeg = spawn(ffmpegPath, args);

          ffmpeg.on("close", (code) => {
            if (code === 0) {
              console.log("ffmpeg conversion successful");
              resolve();
            } else {
              reject(new Error("ffmpeg process exited with code " + code));
            }
          });
          ffmpeg.on("error", (err) => reject(err));
        });

        // 4) Upload all the generated HLS files (.m3u8 + .ts) to Storage
        //    We'll place them in a folder like `videos/hls/<fileName>/*`
        const hlsStoragePath = `videos/hls/${fileName}`;
        const files = fs.readdirSync(hlsOutputFolder);
        for (const hlsFile of files) {
          const localPath = path.join(hlsOutputFolder, hlsFile);
          const remotePath = path.join(hlsStoragePath, hlsFile);
          await bucket.upload(localPath, {destination: remotePath});
        }
        console.log("HLS segments uploaded to:", hlsStoragePath);

        // 5) Optionally, generate a **public** or **signed** URL for the .m3u8
        //    We'll rely on `videos/hls/<fileName>/output.m3u8`.
        const manifestFile = bucket.file(`${hlsStoragePath}/output.m3u8`);

        //  a) Make the file publicly readable (requires uniform bucket-level access
        //      or appropriate IAM policy).
        //      await manifestFile.makePublic();
        //      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${hlsStoragePath}/output.m3u8`;
        //      return { hlsURL: publicUrl };

        //   b) Or generate a signed URL (valid for e.g. 24 hours)
        const [url] = await manifestFile.getSignedUrl({
          action: "read",
          expires: Date.now() + 24 * 60 * 60 * 1000, // 24 hours
        });

        console.log("Returning HLS URL:", url);

        // 6) Cleanup local temp files to avoid filling up the ephemeral storage
        fs.unlinkSync(tempLocalFile);
        fs.rmSync(hlsOutputFolder, {recursive: true, force: true});
        // Return the .m3u8 link
        return {
          hlsURL: url,
          hlsPath: hlsStoragePath,
        };
      } catch (err) {
        console.error("Error in convertVideoToHLS:", err);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to convert to HLS",
            err.message,
        );
      }
    });
