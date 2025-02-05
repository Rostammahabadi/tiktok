import SwiftUI
import UIKit
import VideoEditorSDK

class ShowVideoEditor: NSObject {
    weak var presentingViewController: UIViewController?
    
    func invokeExample() {
        // Create a Video from a URL to a video in the app bundle.
        guard let url = Bundle.main.url(forResource: "Skater", withExtension: "mp4") else { return }
        let video = VideoEditorSDK.Video(url: url)
        
        // Create the View that hosts the video editor.
        var videoEditor = VideoEditorSwiftUIView(video: video)
        
        // Since we are using UIKit in this example, we need to pass a dismiss action for the
        // View being able to dismiss the presenting UIViewController.
        videoEditor.dismissAction = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true)
        }
        
        // Present the video editor via a UIHostingController.
        let hostingController = UIHostingController(rootView: videoEditor)
        hostingController.modalPresentationStyle = .fullScreen
        presentingViewController?.present(hostingController, animated: true)
    }
}

// A View that hosts the VideoEditor in order
// to use it in this UIKit example application.
struct VideoEditorSwiftUIView: View {
    // The action to dismiss the view.
    internal var dismissAction: (() -> Void)?
    
    // The video being edited.
    let video: VideoEditorSDK.Video
    
    var body: some View {
        VideoEditor(video: video)
            .onDidSave { result in
                // The user exported a new video successfully and the newly generated video is located at result.output.url
                print("Received video at \(result.output.url.absoluteString)")
                dismissAction?()
            }
            .onDidCancel {
                // The user tapped on the cancel button within the editor
                dismissAction?()
            }
            .onDidFail { error in
                // There was an error generating the video
                print("Editor finished with error: \(error.localizedDescription)")
                dismissAction?()
            }
            .ignoresSafeArea()
    }
}
