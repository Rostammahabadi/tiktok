import UIKit
import VideoEditorSDK
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions
import FirebaseCore
import AVFoundation
import FirebaseAuth

class SaveVideoToRemoteURL: NSObject {
    weak var presentingViewController: UIViewController?
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    // MARK: - Public Entry Point
    /// Call this method after the user finishes editing in VideoEditorSDK.
    ///
    /// - Parameters:
    ///   - mainVideoURL: The final exported video from PESDK (`result.output.url`).
    ///   - result: The `VideoEditorResult` containing segments, serialization, etc.
    ///
    func uploadEditedVideoWithSegments(mainVideoURL: URL,
                                       result: VideoEditorResult,
                                       serializedData: Data?) {
        // 1) Auth check
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            return
        }
        
        // 2) Create a new "project" document in Firestore
        let projectRef = db.collection("projects").document()
        let projectId = projectRef.documentID
        
        // 3) Upload each segment to /users/{userId}/projects/{projectId}/videos/{segmentId}.mp4
        //    And create a Firestore doc in "videos" for each segment
        Task {
            do {
                // Optional: You can create the project doc right away (e.g., with partial data)
                // and update it later once the thumbnail is generated, etc.
                // For simplicity, let's gather some data first:
                
                // 3a) Upload all segments
                var segmentDocuments: [String] = []
                
                for segment in result.task.video.segments {
                    let segmentDocRef = db.collection("videos").document()
                    let segmentId = segmentDocRef.documentID
                    print("📝 Segment ID: \(segmentId)")
                    // Path in Firebase Storage
                    let segmentStoragePath = "users/\(userId)/projects/\(projectId)/videos/\(segmentId).mp4"
                    let segmentRef = storage.reference().child(segmentStoragePath)
                    
                    // Upload the segment file
                    do {
                        let processedSegmentURL = try await processVideoAsMP4(from: segment.url)
                        let _ = try await segmentRef.putFileAsync(from: processedSegmentURL)
                        print("✅ Uploaded segment: \(segmentId)")
                        let downloadURL = try await segmentRef.downloadURL()
                        print("✅ Download URL: \(downloadURL.absoluteString)")
                        // 3b) Write segment metadata to Firestore
                        var segmentData: [String: Any] = [
                            "author_id": userId,
                            "project_id": projectId,
                            "url": downloadURL.absoluteString,
                            "storagePath": segmentStoragePath,
                            "is_deleted": false,
                            "created_at": FieldValue.serverTimestamp(),
                        ]
                        print("✅ Segment data: \(segmentData)")
                        segmentData["startTime"] = segment.startTime ?? NSNull()
                        segmentData["endTime"] = segment.endTime ?? NSNull()
                        print("✅ Segment data: \(segmentData)")
                        try await segmentDocRef.setData(segmentData)
                        print("✅ Segment doc created: \(segmentId)")
                        segmentDocuments.append(segmentId)
                    } catch {
                        print("❌ Error uploading segment \(segmentId): \(error.localizedDescription)")
                    }
                }
                
                // 4) Process & upload the main final video to /videos/original/{videoId}.mov
                //    Then store that doc in Firestore for HLS conversion
                let mainVideoId = UUID().uuidString
                let mainVideoPath = "videos/original/\(mainVideoId).mov" // or .mp4, up to you
                let mainVideoRef = storage.reference().child(mainVideoPath)
                
                print("📤 Processing main video...")
                let processedURL = try await processVideoAsMOV(from: mainVideoURL)
                
                // Generate thumbnail for main video
                let mainThumbnailPath = "videos/thumbnails/\(mainVideoId).jpg"
                let thumbnailRef = storage.reference().child(mainThumbnailPath)
                var mainThumbnailURL: URL?
                
                if let thumbnailData = try? await generateThumbnail(from: processedURL) {
                    do {
                        try await thumbnailRef.putDataAsync(thumbnailData)
                        mainThumbnailURL = try? await thumbnailRef.downloadURL()
                    } catch {
                        print("❌ Error uploading main thumbnail: \(error.localizedDescription)")
                    }
                }
                
                // Actually upload the processed main video
                print("📤 Uploading main video to \(mainVideoPath)")
                try await mainVideoRef.putFileAsync(from: processedURL)
                let finalMainVideoURL = try await mainVideoRef.downloadURL()
                
                // 4b) Create the Firestore doc for the main video
                let mainVideoDocData: [String: Any] = [
                    "author_id": userId,
                    "project_id": projectId,
                    "originalUrl": finalMainVideoURL.absoluteString,
                    "originalPath": mainVideoPath,
                    "thumbnailUrl": mainThumbnailURL?.absoluteString ?? NSNull(),
                    "thumbnailPath": mainThumbnailPath,
                    "created_at": FieldValue.serverTimestamp(),
                    "status": "processing", // will be updated after HLS
                    "is_deleted": false
                ]
                try await db.collection("videos").document(mainVideoId).setData(mainVideoDocData)
                
                print("✅ Main video doc created: \(mainVideoId)")
                
                // 5) Create the project doc with serialization, referencing the main video
                var projectData: [String: Any] = [
                    "author_id": userId,
                    "created_at": FieldValue.serverTimestamp(),
                    "main_video_id": mainVideoId,
                    "segment_ids": segmentDocuments, // array of references if you like
                    "thumbnail_url": mainThumbnailURL?.absoluteString ?? NSNull()
                ]
                
                // If you have serialized settings from PESDK:
                if let serializedData = serializedData,
                let serializationJSON = try? JSONSerialization.jsonObject(with: serializedData) as? [String: Any]
                {
                    projectData["serialization"] = serializationJSON
                }
                
                try await projectRef.setData(projectData)
                print("✅ Project doc created: \(projectId)")
                
                // 6) Trigger HLS conversion for the main video
                self.convertToHLS(filePath: mainVideoPath, videoId: mainVideoId)
                
                print("🎉 All done! Segments uploaded, main video uploaded, project doc created, HLS triggered.")
                
            } catch {
                print("❌ Error while uploading edited video with segments: \(error.localizedDescription)")
            }
        }
    }
    
    func processVideoAsMP4(from sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        
        // Attempt to create an export session
        guard let exportSession = AVAssetExportSession(asset: asset,
                                                       presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "ReexportVideoSegment",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }
        
        // Generate a stable temp file path for the .mp4
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Perform the export asynchronously
        await exportSession.export()
        
        // Check export status
        guard exportSession.status == .completed else {
            // If there's an underlying error, throw it; otherwise, create a generic one.
            if let error = exportSession.error {
                throw error
            } else {
                throw NSError(domain: "ReexportVideoSegment",
                              code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "Export session did not complete"])
            }
        }
        
        // Return the new file URL
        return outputURL
    }
    
    // MARK: - Thumbnail Generation
    private func generateThumbnail(from videoURL: URL) async throws -> Data? {
        let asset = AVURLAsset(url: videoURL)
        
        // Load tracks (async)
        try await asset.load(.tracks)
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.7)
    }
    
    // MARK: - Process Video (Export as .mov)
    /// If you want to keep the final extension `.mov`, set `outputFileType = .mov`.
    private func processVideoAsMOV(from sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        
        // Load required asset properties
        try await asset.load(.tracks, .duration)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "SaveVideoToRemoteURL", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create export session"
            ])
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).mov")
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(
                domain: "SaveVideoToRemoteURL",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Export failed with status: \(exportSession.status.rawValue)"]
            )
        }
        
        return tempURL
    }
    
    // MARK: - HLS Conversion
    func convertToHLS(filePath: String, videoId: String) {
        print("🎬 Starting HLS conversion for video: \(videoId)")
        
        db.collection("videos").document(videoId).getDocument { (document, error) in
            if let error = error {
                print("❌ Firestore error: \(error.localizedDescription)")
                return
            }
            guard let document = document, document.exists else {
                print("❌ Video document not found in Firestore.")
                return
            }
            
            // Confirm the originalPath if needed
            guard let originalPath = document.get("originalPath") as? String else {
                print("❌ Missing originalPath in Firestore doc.")
                return
            }
            
            // Construct the Cloud Function URL
            guard let projectID = FirebaseApp.app()?.options.projectID else {
                print("❌ Could not get Firebase project ID")
                return
            }
            
            let functionRegion = "us-central1"
            let functionURLString = "https://\(functionRegion)-\(projectID).cloudfunctions.net/convertVideoToHLS"
            guard let functionURL = URL(string: functionURLString) else {
                print("❌ Invalid function URL: \(functionURLString)")
                return
            }
            
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody: [String: Any] = ["filePath": originalPath]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
                request.httpBody = jsonData
            } catch {
                print("❌ Failed to serialize request body: \(error.localizedDescription)")
                return
            }
            
            // Perform the call
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from HLS function")
                    return
                }
                
                do {
                    if let responseJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("📦 HLS Function Response: \(responseJSON)")
                        
                        if httpResponse.statusCode == 200 {
                            if let hlsPath = responseJSON["hlsPath"] as? String,
                               let hlsURL = responseJSON["hlsURL"] as? String {
                                
                                print("✅ HLS conversion successful for video: \(videoId)")
                                // Update Firestore doc with HLS info
                                let updateData: [String: Any] = [
                                    "status": "completed",
                                    "hlsPath": "\(hlsPath)/output.m3u8",
                                    "hlsUrl": hlsURL,
                                    "type": "hls"
                                ]
                                
                                self.db.collection("videos").document(videoId).updateData(updateData) { err in
                                    if let err = err {
                                        print("❌ Failed to update Firestore with HLS info: \(err.localizedDescription)")
                                    } else {
                                        print("✅ Updated Firestore doc with HLS info.")
                                    }
                                }
                            } else {
                                print("❌ Missing hlsPath/hlsURL in function response.")
                            }
                        } else {
                            let errorMsg = responseJSON["error"] as? String ?? "Unknown HLS function error"
                            print("❌ HLS function returned error: \(errorMsg)")
                        }
                    }
                } catch {
                    print("❌ Failed to parse HLS response: \(error.localizedDescription)")
                    if let responseStr = String(data: data, encoding: .utf8) {
                        print("📝 Raw response: \(responseStr)")
                    }
                }
            }
            
            task.resume()
        }
    }
}
