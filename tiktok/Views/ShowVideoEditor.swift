import SwiftUI
import VideoEditorSDK
import Photos
import AVFoundation
import UIKit
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions

class ShowVideoEditor: NSObject {
    weak var presentingViewController: UIViewController?
    private let saveVideoService = SaveVideoToRemoteURL()
    
    func showVideoEditor() {
        guard let url = Bundle.main.url(forResource: "Skater", withExtension: "mp4") else { return }
        let video = VideoEditorSDK.Video(url: url)
        var videoEditor = VideoEditorSwiftUIView(video: video)
        
        // Configure video export settings
        let configuration = Configuration { builder in
            builder.configureVideoEditViewController { options in
                // Use MP4 container for maximum compatibility
                options.videoContainerFormat = .mp4
                
                // Use H.264 with high profile and auto level for best quality/compatibility balance
                // Using a higher bitrate (8000 kbps) for better quality
                options.videoCodec = .h264(withBitRate: 8000, profile: .HighAutoLevel)
                
                // Force export to ensure consistent output
                options.forceExport = true
            }
        }
        
        videoEditor.dismissAction = {
            self.presentingViewController?.dismiss(animated: true, completion: nil)
        }
        
        videoEditor.saveVideoAction = { result in
            // Set the presentingViewController before upload
            self.saveVideoService.presentingViewController = self.presentingViewController
            self.saveVideoService.uploadVideo(from: result.output.url, result: result)
        }
        
        // Create editor with configuration
        let hostingController = UIHostingController(rootView: videoEditor)
        hostingController.modalPresentationStyle = .fullScreen
        presentingViewController?.present(hostingController, animated: true, completion: nil)
    }
}

struct VideoEditorSwiftUIView: View {
    // The action to dismiss the view.
    internal var dismissAction: (() -> Void)?
    internal var saveVideoAction: ((VideoEditorResult) -> Void)?
    
    // The video being edited.
    let video: VideoEditorSDK.Video
    
    var body: some View {
        VideoEditor(video: video)
            .onDidSave { result in
                print("📹 Received video at \(result.output.url.absoluteString)")
                saveVideoAction?(result)
                dismissAction?()
            }
            .onDidCancel {
                print("🚫 Editor cancelled")
                dismissAction?()
            }
            .onDidFail { error in
                print("❌ Editor failed: \(error.localizedDescription)")
                dismissAction?()
            }
            // In order for the editor to fill out the whole screen it needs
            // to ignore the safe area.
            .ignoresSafeArea()
    }
}
