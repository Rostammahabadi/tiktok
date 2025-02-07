import SwiftUI
import VideoEditorSDK
import FirebaseFirestore
import FirebaseAuth
import AVFoundation

struct EditExistingVideoView: UIViewControllerRepresentable {
    let videoURLs: [Video]
    let project: Project
    
    var configuration: Configuration = {
        Configuration { builder in
            builder.theme = .dark
            builder.assetCatalog = AssetCatalog.defaultItems
        }
    }()
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VideoEditViewControllerDelegate {
        private let parent: EditExistingVideoView
        
        init(_ parent: EditExistingVideoView) {
            self.parent = parent
        }
        
        func videoEditViewControllerDidFail(_ videoEditViewController: VideoEditViewController, error: VideoEditorError) {
            print("❌ Editor error: \(error.localizedDescription)")
            videoEditViewController.dismiss(animated: true)
        }
        
        func videoEditViewControllerDidFinish(_ videoEditViewController: VideoEditViewController, result: VideoEditorResult) {
            videoEditViewController.dismiss(animated: true)
            
            // Get current user
            guard let userId = Auth.auth().currentUser?.uid else {
                print("❌ No authenticated user.")
                return
            }
            
            // Process the edited video
            Task {
                do {
                    let db = Firestore.firestore()
                    
                    // Create new project
                    let projectRef = db.collection("projects").document()
                    let projectId = projectRef.documentID
                    
                    // Generate and upload thumbnail
                    print("🖼 Generating thumbnail")
                    let thumbnail = try ThumbnailService.shared.generateThumbnail(from: result.output.url)
                    let thumbnailUrl = try await ThumbnailService.shared.uploadThumbnail(thumbnail, projectId: projectId)
                    print("✅ Thumbnail generated and uploaded")
                    
                    // Upload each segment
                    var processedSegments: [[String: Any]] = []
                    
                    for segment in result.task.video.segments {
                        print("📤 Uploading segment")
                        let segmentStorageUrl = try await StorageService.shared.uploadVideo(from: segment.url, projectId: projectId)
                        
                        var segmentData: [String: Any] = [
                            "url": segmentStorageUrl.absoluteString
                        ]
                        
                        if let startTime = segment.startTime {
                            segmentData["startTime"] = startTime
                        }
                        if let endTime = segment.endTime {
                            segmentData["endTime"] = endTime
                        }
                        
                        processedSegments.append(segmentData)
                        print("✅ Processed segment")
                    }
                    
                    // Get serialized settings
                    guard let serializedData = videoEditViewController.serializedSettings,
                          let serialization = try? JSONSerialization.jsonObject(with: serializedData, options: []) as? [String: Any] else {
                        print("⚠️ Could not serialize editor settings")
                        return
                    }
                    
                    // Create project document with all URLs
                    let project: [String: Any] = [
                        "author_id": userId,
                        "created_at": FieldValue.serverTimestamp(),
                        "thumbnail_url": thumbnailUrl.absoluteString,
                        "original_urls": parent.videoURLs.map { $0 },
                        "serialization": serialization,
                    ]
                    
                    try await projectRef.setData(project)
                    print("✅ Created project \(projectId)")
                    
                    // Create video documents
                    let videosCollection = db.collection("videos")
                    for segment in processedSegments {
                        let videoRef = videosCollection.document()
                        print("📝 Creating video document: \(videoRef.documentID)")
                        
                        try await videoRef.setData([
                            "author_id": userId,
                            "project_id": projectId,
                            "url": segment["url"] as! String,
                            "startTime": segment["startTime"] ?? NSNull(),
                            "endTime": segment["endTime"] ?? NSNull()
                        ])
                        print("✅ Created video document: \(videoRef.documentID)")
                    }
                    
                } catch {
                    print("❌ Error processing video: \(error.localizedDescription)")
                }
            }
        }
        
        func videoEditViewControllerDidCancel(_ videoEditViewController: VideoEditViewController) {
            videoEditViewController.dismiss(animated: true)
        }
    }
    
    func makeUIViewController(context: Context) -> VideoEditViewController {
        // Create video segments from URLs
        let segments = videoURLs.map { video -> VideoEditorSDK.VideoSegment in
            guard let url = URL(string: video.url) else {
                fatalError("Invalid URL: \(video.url)")
            }
            return VideoEditorSDK.VideoSegment(url: url, startTime: video.startTime, endTime: video.endTime)
        }
        
        // Create a video from the segments
        let video = VideoEditorSDK.Video(segments: segments)
        
        // Create and configure the editor
        let videoEditVC: VideoEditViewController
        
        if let serializedSettings = project.serializedSettings {
            // Deserialize the saved settings
            let deserializationResult = Deserializer.deserialize(
                data: serializedSettings,
                imageDimensions: video.size,
                assetCatalog: configuration.assetCatalog
            )
            
            // Get the PhotoEditModel from deserialization
            if let photoEditModel = deserializationResult.model {
                videoEditVC = VideoEditViewController(
                    videoAsset: video,
                    configuration: configuration,
                    photoEditModel: photoEditModel
                )
            } else {
                print("⚠️ Failed to deserialize settings, creating new editor")
                videoEditVC = VideoEditViewController(
                    videoAsset: video,
                    configuration: configuration
                )
            }
        } else {
            // Create new editor without serialized settings
            videoEditVC = VideoEditViewController(
                videoAsset: video,
                configuration: configuration
            )
        }
        
        // Load serialized settings if available
//        if let serializedSettings = project.serializedSettings {
//            videoEditVC.loadSettings(serializedSettings)
//        }
        
        // Set delegate
        videoEditVC.delegate = context.coordinator
        
        return videoEditVC
    }
    
    func updateUIViewController(_ uiViewController: VideoEditViewController, context: Context) {}
}
