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
            
            let db = Firestore.firestore()
            
            // 2) Create a "project" doc
            let projectRef = db.collection("projects").document()
            let projectId = projectRef.documentID
            
            // 3) Basic metadata for the project
            let project: [String: Any] = [
                "author_id": userId,
                "title": "Video Project",
                "description": "User's video creation",
                "status": "created",
                "created_at": FieldValue.serverTimestamp()
            ]
            
            // 4) Save the project
            projectRef.setData(project) { error in
                if let error = error {
                    print("❌ Error creating project doc: \(error.localizedDescription)")
                    return
                }
                print("✅ Created project \(projectId)")
                
                // 5) Once the project doc is created, save the final video + serialization
                self.saveVideoData(for: videoEditViewController, result: result, in: projectId, db: db)
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
        
        // MARK: - Helper
        
        private func saveVideoData(for videoEditViewController: ImglyKit.VideoEditViewController,
                                   result: ImglyKit.VideoEditorResult,
                                   in projectId: String,
                                   db: Firestore) {
            // 1) Get the final exported video URL
            let exportedUrl = result.output.url
            
            // 2) Serialize the editor settings
            guard let serializedData = videoEditViewController.serializedSettings else {
                print("⚠️ No serializedSettings available.")
                return
            }
            
            // Convert to Dictionary
            guard let serialization = try? JSONSerialization.jsonObject(with: serializedData, options: []) as? [String: Any] else {
                print("⚠️ Could not parse serializedSettings.")
                return
            }
            
            // 3) Capture multi-clip segments if needed
            //    (Each segment is a chunk of the final timeline)
            let segments = result.task.video.segments.map { segment -> [String: Any] in
                return [
                    "url": segment.url.absoluteString,
                    "startTime": segment.startTime ?? NSNull(),
                    "endTime": segment.endTime ?? NSNull()
                ]
            }
            
            // 4) Create a "video" doc
            let videoRef = db.collection("videos").document()
            let videoId = videoRef.documentID
            
            // 5) Video data
            let video: [String: Any] = [
                "author_id": Auth.auth().currentUser?.uid,
                "project_id": projectId,
                "exported_file_path": exportedUrl.absoluteString,
                "segments": segments,
                "serialization": serialization,
                "saved_at": FieldValue.serverTimestamp()
            ]
            
            // 6) Save in top-level collection "videos"
            videoRef.setData(video) { error in
                if let error = error {
                    print("❌ Error saving video data: \(error.localizedDescription)")
                    return
                }
                print("✅ Video data saved for project \(projectId)")
            }
        }
    }
}
