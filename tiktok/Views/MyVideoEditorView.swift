import SwiftUI
import VideoEditorSDK
import FirebaseFirestore
import FirebaseAuth
import Swift

struct MyVideoEditorView: UIViewControllerRepresentable {
    let videoURL: URL
    var configuration: Configuration = {
        Configuration { builder in
            // For instance, set the theme to dark
            builder.theme = .dark
            
            // Other customizations, e.g.:
            // builder.configureTransformToolController { options in
            //     options.allowFreeCrop = false
            // }
        }
    }()
    
    func makeUIViewController(context: Context) -> VideoEditViewController {
        // 1. Create your `Video` model
        let video = VideoEditorSDK.Video(url: videoURL)
        
        // 2. Create the video editor view controller
        let videoEditVC = VideoEditViewController(videoAsset: video, configuration: configuration)
        
        // 3. Set the delegate to your Coordinator
        videoEditVC.delegate = context.coordinator
        
        return videoEditVC
    }
    
    func updateUIViewController(_ uiViewController: VideoEditViewController,
                                context: Context) {
        // no-op (usually)
    }
    
    // MARK: - Coordinator
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VideoEditViewControllerDelegate {
        func videoEditViewControllerDidFail(_ videoEditViewController: ImglyKit.VideoEditViewController, error: ImglyKit.VideoEditorError) {
            print("failed")
        }
        
        let parent: MyVideoEditorView
        
        init(_ parent: MyVideoEditorView) {
            self.parent = parent
        }
        
        // MARK: - VideoEditViewControllerDelegate
        
        // This is the main callback where you get both the `videoEditViewController.serializedSettings`
        // and the `result` which includes final video export info & segments.
        func videoEditViewControllerDidFinish(_ videoEditViewController: ImglyKit.VideoEditViewController,
                                              result: ImglyKit.VideoEditorResult) {
            videoEditViewController.dismiss(animated: true)
            
            // 1) Basic Auth check
            guard let userId = Auth.auth().currentUser?.uid else {
                print("❌ No authenticated user.")
                return
            }
            
            // 1) Get all the video URLs we need to process
            let exportedUrl = result.output.url
            var segmentUrls: [(URL, [String: Any])] = []
            
            for segment in result.task.video.segments {
                segmentUrls.append((
                    segment.url,
                    [
                        "startTime": segment.startTime ?? NSNull(),
                        "endTime": segment.endTime ?? NSNull()
                    ]
                ))
            }
            
            // 2) Process all videos while they're still in temp directory
            Task {
                do {
                    let db = Firestore.firestore()
                    
                    // Get the current highest order number
                    let snapshot = try await db.collection("videos")
                        .whereField("author_id", isEqualTo: userId)
                        .order(by: "order", descending: true)
                        .limit(to: 1)
                        .getDocuments()
                    
                    // Create project first
                    let projectRef = db.collection("projects").document()
                    let projectId = projectRef.documentID
                    
                    // Generate and upload thumbnail
                    print("🖼 Generating thumbnail")
                    let thumbnail = try await ThumbnailService.shared.generateThumbnail(from: exportedUrl)
                    let thumbnailUrl = try await ThumbnailService.shared.uploadThumbnail(thumbnail, projectId: projectId)
                    print("✅ Thumbnail generated and uploaded")
                    
                    // Upload each segment and collect their data
                    var processedSegments: [[String: Any]] = []
                    
                    for (index, (segmentUrl, segmentData)) in segmentUrls.enumerated() {
                        print("📤 Uploading segment \(index + 1)")
                        let segmentStorageUrl = try await StorageService.shared.uploadVideo(from: segmentUrl, projectId: projectId)
                        
                        var segment = segmentData
                        print("segment: \(segment)")
                        segment["url"] = segmentStorageUrl.absoluteString
                        processedSegments.append(segment)
                        print("✅ Processed segment \(index + 1)")
                    }
                    
                    // Serialize the editor settings
                    guard let serializedData = videoEditViewController.serializedSettings,
                          let serialization = try? JSONSerialization.jsonObject(with: serializedData, options: []) as? [String: Any] else {
                        print("⚠️ Could not serialize editor settings")
                        return
                    }
                    
                    let project: [String: Any] = [
                        "author_id": userId,
                        "title": "Video Project",
                        "description": "User's video creation",
                        "status": "created",
                        "created_at": FieldValue.serverTimestamp(),
                        "thumbnail_url": thumbnailUrl.absoluteString,
                        // "segments": processedSegments,
                        "serialization": serialization,
                    ]
                    
                    try await projectRef.setData(project)
                    print("✅ Created project \(projectId)")
                    
                    // Upload main video
                    let mainVideoUrl = try await StorageService.shared.uploadVideo(from: exportedUrl, projectId: projectId)
                    print("✅ Uploaded main video")
                    
                    
                    // Create video documents for each segment
                    let videosCollection = db.collection("videos")
                    var order = 0
                    for segment in processedSegments {
                        // Create a new document for each segment
                        let videoRef = videosCollection.document()
                        print("📝 Creating video document: \(videoRef.documentID)")
                        
                        try await videoRef.setData([
                            "author_id": userId,
                            "project_id": projectId,
                            "url": segment["url"] as! String,
                            "startTime": segment["startTime"] ?? NSNull(),
                            "endTime": segment["endTime"] ?? NSNull(),
                            "order": order,
                            "is_deleted": false
                        ])
                        print("✅ Created video document: \(videoRef.documentID)")
                        order += 1
                    }
                    
                } catch {
                    print("❌ Error processing video: \(error.localizedDescription)")
                }
            }
        }
        
        // Called if the user cancels (without exporting)
        func videoEditViewControllerDidCancel(_ videoEditViewController: VideoEditViewController) {
            videoEditViewController.dismiss(animated: true)
            print("🚫 Editor cancelled")
        }
        
        func videoEditViewController(_ videoEditViewController: VideoEditViewController,
                                     didFailWith error: Error) {
            videoEditViewController.dismiss(animated: true)
            print("❌ Editor error: \(error)")
        }
    }
}
