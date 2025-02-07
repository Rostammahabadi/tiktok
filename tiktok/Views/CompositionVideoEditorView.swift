import SwiftUI
import VideoEditorSDK
import FirebaseFirestore
import FirebaseAuth
import AVFoundation

struct CompositionVideoEditorView: UIViewControllerRepresentable {
    let mainVideoURL: URL
    let additionalClips: [VideoClip]
    let serializedSettings: Data?
    
    init(mainVideoURL: URL, additionalClips: [URL], serializedSettings: Data? = nil) {
        self.mainVideoURL = mainVideoURL
        
        // Convert URLs to VideoClips with unique identifiers
        self.additionalClips = additionalClips.enumerated().map { index, url in
            VideoClip(identifier: "clip_\(index)", videoURL: url)
        }
        self.serializedSettings = serializedSettings
    }
    
    private var configuration: Configuration {
        Configuration { builder in
            // Set up the base theme
            builder.theme = .dark
            
            // Create video clip categories
            let allClipsCategory = VideoClipCategory(
                title: "All Clips",
                imageURL: nil,
                videoClips: additionalClips
            )
            
            // Add clips to asset catalog
            builder.assetCatalog.videoClips = [allClipsCategory]
            
            // Configure composition tool
            builder.configureCompositionToolController { options in
                // Use predefined clips instead of image picker
                options.videoClipLibraryMode = .predefined
            }
            
            // Configure video clip selection
            builder.configureVideoClipToolController { options in
                // Disable personal video clips, only use predefined ones
                options.personalVideoClipsEnabled = false
                options.defaultVideoClipCategoryIndex = 0
            }
        }
    }
    
    func makeUIViewController(context: Context) -> VideoEditViewController {
        // Create the main video
        let video = VideoEditorSDK.Video(url: mainVideoURL)
        
        // Create editor with deserialized settings if available
        let videoEditVC: VideoEditViewController
        
        if let serializedSettings = serializedSettings {
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
        
        // Set delegate
        videoEditVC.delegate = context.coordinator
        
        return videoEditVC
    }
    
    func updateUIViewController(_ uiViewController: VideoEditViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VideoEditViewControllerDelegate {
        private let parent: CompositionVideoEditorView
        
        init(_ parent: CompositionVideoEditorView) {
            self.parent = parent
        }
        
        func videoEditViewControllerShouldStart(_ videoEditViewController: VideoEditViewController, task: VideoEditorTask) -> Bool {
            // Allow all tasks
            return true
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
                    let thumbnail = try await ThumbnailService.shared.generateThumbnail(from: result.output.url)
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
                        "main_video_url": parent.mainVideoURL.absoluteString,
                        "additional_clip_urls": parent.additionalClips.map { $0.videoURL.absoluteString },
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
}
