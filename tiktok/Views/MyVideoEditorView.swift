import SwiftUI
import VideoEditorSDK
import FirebaseFirestore
import FirebaseAuth
import Swift

struct MyVideoEditorView: UIViewControllerRepresentable {
    let videoURL: URL
    @Binding var showBirdAnimation: Bool
    @Binding var isUploading: Bool
    
    var configuration: Configuration = {
        Configuration { builder in
            builder.theme = .dark
        }
    }()
    
    func makeUIViewController(context: Context) -> VideoEditViewController {
        let video = VideoEditorSDK.Video(url: videoURL)
        let videoEditVC = VideoEditViewController(videoAsset: video, configuration: configuration)
        videoEditVC.delegate = context.coordinator
        return videoEditVC
    }
    
    func updateUIViewController(_ uiViewController: VideoEditViewController,
                                context: Context) {
        // no-op
    }
    
    // MARK: - Coordinator
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VideoEditViewControllerDelegate {
        func videoEditViewControllerDidFail(_ videoEditViewController: ImglyKit.VideoEditViewController, error: ImglyKit.VideoEditorError) {
            print("failed")
            parent.showBirdAnimation = false
            parent.isUploading = false
            videoEditViewController.dismiss(animated: true)
        }
        
        let parent: MyVideoEditorView
        
        init(_ parent: MyVideoEditorView) {
            self.parent = parent
        }
        
        // MARK: - VideoEditViewControllerDelegate
        func videoEditViewControllerDidFinish(_ videoEditViewController: ImglyKit.VideoEditViewController,
                                              result: ImglyKit.VideoEditorResult) {
            // Show bird animation immediately when user finishes editing
            parent.showBirdAnimation = true
            parent.isUploading = true
            
            // 1) Basic Auth check
            guard let userId = Auth.auth().currentUser?.uid else {
                print("❌ No authenticated user.")
                parent.showBirdAnimation = false
                parent.isUploading = false
                videoEditViewController.dismiss(animated: true)
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
                    }
                    
                    // Get serialization data
                    guard let serializedData = videoEditViewController.serializedSettings,
                          let serialization = try? JSONSerialization.jsonObject(with: serializedData, options: []) as? [String: Any] else {
                        print("⚠️ Could not serialize editor settings")
                        parent.showBirdAnimation = false
                        parent.isUploading = false
                        videoEditViewController.dismiss(animated: true)
                        return
                    }
                    
                    guard !processedSegments.isEmpty else {
                        print("❌ No segments to process")
                        parent.showBirdAnimation = false
                        parent.isUploading = false
                        videoEditViewController.dismiss(animated: true)
                        return
                    }
                    
                    // Create project document with all URLs
                    let project: [String: Any] = [
                        "author_id": userId,
                        "created_at": FieldValue.serverTimestamp(),
                        "thumbnail_url": thumbnailUrl.absoluteString,
                        "original_urls": parent.videoURL.absoluteString,
                        "serialization": serialization,
                    ]
                    
                    try await projectRef.setData(project)
                    print("✅ Created project \(projectId)")
                    
                    // Create video documents
                    let videosCollection = db.collection("videos")
                    var order = 0
                    for segment in processedSegments {
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
                    
                    // All done - dismiss after a short delay to show completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.parent.isUploading = false
                        videoEditViewController.dismiss(animated: true)
                    }
                    
                } catch {
                    print("❌ Error processing video: \(error.localizedDescription)")
                    parent.showBirdAnimation = false
                    parent.isUploading = false
                    videoEditViewController.dismiss(animated: true)
                }
            }
        }
        
        // Called if the user cancels (without exporting)
        func videoEditViewControllerDidCancel(_ videoEditViewController: VideoEditViewController) {
            videoEditViewController.dismiss(animated: true)
        }
    }
}

// MARK: - UIViewControllerRepresentable Wrapper for GraduationBirdAnimation
struct MyVideoEditorViewWrapper: View {
    let videoURL: URL
    @State private var showBirdAnimation = false
    @State private var isUploading = false
    
    var body: some View {
        ZStack {
            MyVideoEditorView(videoURL: videoURL,
                            showBirdAnimation: $showBirdAnimation,
                            isUploading: $isUploading)
            
            if showBirdAnimation {
                GraduationBirdAnimation(isShowing: $showBirdAnimation) {
                    // Only dismiss if we're not still uploading
                    if !isUploading {
                        showBirdAnimation = false
                    }
                }
            }
        }
    }
}
