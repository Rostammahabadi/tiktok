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
    /// Uploads all segments + main video, creates project/video docs, then triggers HLS conversion.
    ///
    /// - Parameters:
    ///   - mainVideoURL: The final exported video from PESDK (`result.output.url`).
    ///   - result: The `VideoEditorResult` containing segments, serialization, etc.
    ///   - serializedData: Optional PESDK serialization data (JSON).
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
        
        Task {
            do {
                // 3) Upload each segment in parallel, create "videos" docs
                let segmentIds = try await uploadSegments(
                    segments: result.task.video.segments,
                    userId: userId,
                    projectId: projectId
                )
                
                // 4) Process + upload the main final video to `/videos/original/{videoId}.mov`
                let mainVideoId = UUID().uuidString
                let mainVideoPath = "videos/original/\(mainVideoId).mov"
                let mainVideoRef = storage.reference().child(mainVideoPath)
                
                // Export to .mov
                let processedURL = try await exportVideo(
                    from: mainVideoURL,
                    fileType: .mov
                )
                
                // Generate a thumbnail for the main video
                let thumbnailData = try? await generateThumbnail(from: processedURL)
                var mainThumbnailURL: URL?
                if let data = thumbnailData {
                    let mainThumbnailPath = "videos/thumbnails/\(mainVideoId).jpg"
                    let thumbnailRef = storage.reference().child(mainThumbnailPath)
                    try await thumbnailRef.putDataAsync(data)
                    mainThumbnailURL = try await thumbnailRef.downloadURL()
                }
                
                // Upload the final .mov
                try await mainVideoRef.putFileAsync(from: processedURL)
                let finalMainVideoURL = try await mainVideoRef.downloadURL()
                
                // Create Firestore doc for the main video
                let mainVideoDocData: [String: Any] = [
                    "author_id": userId,
                    "project_id": projectId,
                    "originalUrl": finalMainVideoURL.absoluteString,
                    "originalPath": mainVideoPath,
                    "thumbnailUrl": mainThumbnailURL?.absoluteString ?? NSNull(),
                    "created_at": FieldValue.serverTimestamp(),
                    "status": "processing", // updated after HLS
                    "is_deleted": false
                ]
                try await db.collection("videos").document(mainVideoId).setData(mainVideoDocData)
                
                // 5) Create the project doc referencing segments + main video
                var projectData: [String: Any] = [
                    "author_id": userId,
                    "created_at": FieldValue.serverTimestamp(),
                    "main_video_id": mainVideoId,
                    "segment_ids": segmentIds,
                    "thumbnail_url": mainThumbnailURL?.absoluteString ?? NSNull()
                ]
                
                // Include serialization JSON if available
                if let serializedData = serializedData,
                   let serializationJSON = try? JSONSerialization.jsonObject(with: serializedData) as? [String: Any] {
                    projectData["serialization"] = serializationJSON
                }
                
                try await projectRef.setData(projectData)
                
                // 6) Trigger HLS conversion for the main video
                convertToHLS(filePath: mainVideoPath, videoId: mainVideoId)
                
                print("🎉 All done! Uploaded segments + main video, created project doc, triggered HLS.")
                
            } catch {
                print("❌ Error while uploading videos: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Upload Segments in Parallel
    /// Exports each segment to `.mp4`, uploads to `/users/{userId}/projects/{projectId}/videos/{segmentId}.mp4`
    /// and creates a Firestore doc in `videos` for each. Returns the array of segment doc IDs.
    private func uploadSegments(segments: [ImglyKit.VideoSegment],
                                userId: String,
                                projectId: String) async throws -> [String] {
        var segmentIds = [String]()
        var order = 0
        // Use a TaskGroup to process segments in parallel
        try await withThrowingTaskGroup(of: String.self) { group in
            for segment in segments {
                group.addTask {
                    // 1) Create a new doc ID for this segment
                    let segmentDocRef = self.db.collection("videos").document()
                    let segmentId = segmentDocRef.documentID
                    
                    // 2) Export to a stable .mp4
                    let segmentURL = try await self.exportVideo(from: segment.url, fileType: .mp4)
                    
                    // 3) Upload .mp4 to Storage
                    let segmentStoragePath = "users/\(userId)/projects/\(projectId)/videos/\(segmentId).mp4"
                    let segmentRef = self.storage.reference().child(segmentStoragePath)
                    _ = try await segmentRef.putFileAsync(from: segmentURL)
                    let downloadURL = try await segmentRef.downloadURL()
                    
                    // 4) Create Firestore doc
                    var segmentData: [String: Any] = [
                        "author_id": userId,
                        "project_id": projectId,
                        "url": downloadURL.absoluteString,
                        "order": order,
                        "storagePath": segmentStoragePath,
                        "type": "segment",
                        "is_deleted": false,
                        "created_at": FieldValue.serverTimestamp(),
                    ]
                    if let startTime = segment.startTime {
                        segmentData["startTime"] = startTime
                    }
                    if let endTime = segment.endTime {
                        segmentData["endTime"] = endTime
                    }
                    
                    try await segmentDocRef.setData(segmentData)
                    order += 1
                    return segmentId
                }
            }
            // Collect results from the group
            for try await segmentId in group {
                segmentIds.append(segmentId)
            }
        }
        
        return segmentIds
    }
    
    // MARK: - Export Video (configurable)
    /// Exports the given video URL to the requested file type (e.g., .mp4 or .mov) at high quality.
    private func exportVideo(from sourceURL: URL, fileType: AVFileType) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        
        // Load required asset properties
        try await asset.load(.tracks, .duration)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "SaveVideoToRemoteURL", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create export session"
            ])
        }
        
        // Construct output path
        let extensionStr = fileType == .mp4 ? ".mp4" : ".mov"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + extensionStr)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = fileType
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(
                domain: "SaveVideoToRemoteURL",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Export failed with status: \(exportSession.status.rawValue)"]
            )
        }
        
        return outputURL
    }
    
    // MARK: - Thumbnail Generation
    private func generateThumbnail(from videoURL: URL) async throws -> Data? {
        let asset = AVURLAsset(url: videoURL)
        try await asset.load(.tracks) // load tracks
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.7)
    }
    
    // MARK: - HLS Conversion
    func convertToHLS(filePath: String, videoId: String) {
        print("🎬 Starting HLS conversion for video: \(videoId)")
        
        db.collection("videos").document(videoId).getDocument { document, error in
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
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            } catch {
                print("❌ Failed to serialize request body: \(error.localizedDescription)")
                return
            }
            
            // Call the function
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      let data = data else {
                    print("❌ Invalid response or no data")
                    return
                }
                
                do {
                    if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
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
