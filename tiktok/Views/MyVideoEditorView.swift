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
            
            // Get serialization data
            Task {
                let serializedData = await videoEditViewController.serializedSettings
                
                // Instantiate the helper
                let saver = SaveVideoToRemoteURL()
                print("✅ Serialization data: \(serializedData)")
                // Kick off the entire upload + project creation + HLS flow
                saver.uploadEditedVideoWithSegments(
                    mainVideoURL: result.output.url,
                    result: result,
                    serializedData: serializedData
                )
                
                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.parent.isUploading = false
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
