import SwiftUI
import VideoEditorSDK
import AVKit
import FirebaseStorage
import Photos
import AVFoundation
import UIKit
import FirebaseFirestore
import FirebaseFunctions

class ShowVideoEditor: NSObject {
    weak var presentingViewController: UIViewController?
    // Keep a strong reference to saveVideoService
    private let saveVideoService = SaveVideoToRemoteURL()

    func showVideoEditor() {
        // Set the presentingViewController before showing the editor
        saveVideoService.presentingViewController = self.presentingViewController
        
        guard let url = Bundle.main.url(forResource: "Skater", withExtension: "mp4") else { return }
        let video = VideoEditorSDK.Video(url: url)
        var videoEditor = VideoEditorSwiftUIView(video: video)

        videoEditor.dismissAction = {
            self.presentingViewController?.dismiss(animated: true, completion: nil)
        }

        videoEditor.saveVideoAction = { result in
            // No need to use optional chaining since saveVideoService is now a strong reference
            self.saveVideoService.uploadVideo(from: result.output.url, result: result)
        }

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
