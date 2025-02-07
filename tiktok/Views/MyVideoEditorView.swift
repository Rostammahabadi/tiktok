import SwiftUI
import VideoEditorSDK
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
        func videoEditViewControllerDidFinish(_ videoEditViewController: ImglyKit.VideoEditViewController, result: ImglyKit.VideoEditorResult) {
             let serializedSettings = videoEditViewController.serializedSettings
             print(serializedSettings)

             let jsonString = String(data: serializedSettings!, encoding: .utf8)
             print(jsonString!)

             // Or to a `Dictionary`.
             let jsonDict = try? JSONSerialization.jsonObject(with: serializedSettings!, options: [])
             print(jsonDict! as Any)

             for segment in result.task.video.segments {
                print("URL:", segment.url, "startTime:", segment.startTime ?? "nil", "endTime:", segment.endTime ?? "nil")
            }

        }
        
        func videoEditViewControllerDidFail(_ videoEditViewController: ImglyKit.VideoEditViewController, error: ImglyKit.VideoEditorError) {
            print("test")
        }
        
        let parent: MyVideoEditorView
        
        init(_ parent: MyVideoEditorView) {
            self.parent = parent
        }
        
        // MARK: - VideoEditViewControllerDelegate
        
        func videoEditViewController(_ videoEditViewController: VideoEditViewController,
                                     didFinishWith result: VideoEditorResult) {
            // Handle saving, uploading, or your advanced logic
            print("🎉 Saved video at \(result.output.url)")
            
            // If you’re presenting modally, remember to dismiss
            videoEditViewController.dismiss(animated: true)
        }
        
        func videoEditViewControllerDidCancel(_ videoEditViewController: VideoEditViewController) {
            // Handle cancellation
            print("🚫 User cancelled video editing")
            
            videoEditViewController.dismiss(animated: true)
        }
        
        func videoEditViewController(_ videoEditViewController: VideoEditViewController,
                                     didFailWith error: Error) {
            // Handle errors
            print("❌ Editor failed with error: \(error)")
            
            videoEditViewController.dismiss(animated: true)
        }
        
        // Optionally implement further delegate methods...
    }
}
