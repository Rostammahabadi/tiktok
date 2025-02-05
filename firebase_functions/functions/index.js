const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();

const {spawn} = require("child_process");
const path = require("path");
const os = require("os");
const fs = require("fs");
const ffmpegPath = require("ffmpeg-static");

exports.convertVideoToHLS = onRequest(
    {
      memory: "2GiB",
      cpu: 2,
      timeoutSeconds: 540,
    },
    async (req, res) => {
      console.log("🔥 Request received:", req.body);
      try {
        if (req.method !== "POST") {
          return res.status(405).json({error: "Method Not Allowed"});
        }

        const filePath = req.body.filePath;
        if (!filePath) {
          return res.status(400).json({error: "Missing 'filePath' parameter in request body"});
        }

        console.log("Starting HLS conversion for:", filePath);

        const bucket = admin.storage().bucket();
        const fileName = path.basename(filePath, ".mp4");
        const tempLocalFile = path.join(os.tmpdir(), fileName + ".mp4");
        const hlsOutputFolder = path.join(os.tmpdir(), fileName + "-hls");
        console.log("Starting HLS conversion for:", filePath);

        // 1) Download the MP4 to local temp storage
        console.log("Downloading source video...");
        await bucket.file(filePath).download({destination: tempLocalFile});
        console.log(`Downloaded video to ${tempLocalFile}`);

        // 2) Create a local folder for HLS output
        fs.mkdirSync(hlsOutputFolder, {recursive: true});

        // 3) Spawn ffmpeg to convert MP4 -> HLS with optimized settings
        console.log("Starting ffmpeg conversion...");
        await new Promise((resolve, reject) => {
          const args = [
            "-i", tempLocalFile,
            // Video settings - optimize for speed
            "-c:v", "h264",
            "-profile:v", "main",
            "-preset", "veryfast", // Faster encoding
            "-crf", "23",
            "-sc_threshold", "0",
            "-g", "48",
            "-keyint_min", "48",
            // Audio settings - optimize bitrate
            "-c:a", "aac",
            "-b:a", "96k", // Reduced audio bitrate
            "-ac", "2",
            // HLS settings - optimize segment size
            "-hls_time", "4", // Longer segments = fewer files
            "-hls_list_size", "0",
            "-hls_segment_type", "mpegts",
            "-hls_segment_filename", path.join(hlsOutputFolder, "segment%03d.ts"),
            // Use hardware acceleration if available
            "-threads", "0",
            "-f", "hls",
            path.join(hlsOutputFolder, "output.m3u8"),
          ];

          console.log(`Spawning ffmpeg with args: ${args.join(" ")}`);
          const ffmpeg = spawn(ffmpegPath, args);

          // Log ffmpeg output for debugging
          ffmpeg.stdout.on("data", (data) => {
            console.log(`ffmpeg stdout: ${data}`);
          });

          ffmpeg.stderr.on("data", (data) => {
            console.log(`ffmpeg stderr: ${data}`);
          });

          ffmpeg.on("close", (code) => {
            if (code === 0) {
              console.log("ffmpeg conversion successful");
              resolve();
            } else {
              reject(new Error(`ffmpeg process exited with code ${code}`));
            }
          });

          ffmpeg.on("error", (err) => reject(err));
        });

        // 4) Upload all the generated HLS files (.m3u8 + .ts) to Storage
        //    We'll place them in a folder like `videos/hls/<fileName>/*`
        const hlsStoragePath = `videos/hls/${fileName}`;
        const files = fs.readdirSync(hlsOutputFolder);

        // Upload files with public read access
        const uploadPromises = files.map(async (hlsFile) => {
          const localPath = path.join(hlsOutputFolder, hlsFile);
          const remotePath = path.join(hlsStoragePath, hlsFile);
          await bucket.upload(localPath, {
            destination: remotePath,
            metadata: {
              cacheControl: "public, max-age=31536000",
            },
          });
        });

        await Promise.all(uploadPromises);
        console.log("HLS segments uploaded to:", hlsStoragePath);

        // Generate signed URLs for all segments
        const signedUrls = await Promise.all(
            files.map(async (hlsFile) => {
              const file = bucket.file(path.join(hlsStoragePath, hlsFile));
              const [url] = await file.getSignedUrl({
                action: "read",
                expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
              });
              return {file: hlsFile, url};
            }),
        );

        // Read and modify the m3u8 file to use signed URLs
        const m3u8Path = path.join(hlsOutputFolder, "output.m3u8");
        let m3u8Content = fs.readFileSync(m3u8Path, "utf8");

        // Replace each .ts reference with its signed URL
        signedUrls.forEach(({file, url}) => {
          if (file.endsWith(".ts")) {
            m3u8Content = m3u8Content.replace(file, url);
          }
        });

        // Write modified m3u8 back to disk
        fs.writeFileSync(m3u8Path, m3u8Content);

        // Upload modified m3u8
        await bucket.upload(m3u8Path, {
          destination: `${hlsStoragePath}/output.m3u8`,
          metadata: {
            cacheControl: "private, max-age=3600",
            contentType: "application/x-mpegURL",
          },
        });

        // Get signed URL for the manifest
        const manifestFile = bucket.file(`${hlsStoragePath}/output.m3u8`);
        const [manifestUrl] = await manifestFile.getSignedUrl({
          action: "read",
          expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
        });

        console.log("Returning HLS URL:", manifestUrl);

        // 6) Cleanup local temp files to avoid filling up the ephemeral storage
        fs.unlinkSync(tempLocalFile);
        fs.rmSync(hlsOutputFolder, {recursive: true, force: true});
        res.status(200).json({hlsURL: manifestUrl, hlsPath: hlsStoragePath});
      } catch (err) {
        console.error("Error in convertVideoToHLS:", err);
        res.status(500).json({error: "Failed to convert to HLS", details: err.message});
      }
    });
