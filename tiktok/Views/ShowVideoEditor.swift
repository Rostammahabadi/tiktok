import SwiftUI
import VideoEditorSDK
import AVKit
import FirebaseStorage
import Photos
import AVFoundation
import UIKit
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

// Helper extension for replacing default icons with custom icons
private extension UIImage {
    /// Create a new icon image for a specific size by centering the input image and optionally applying alpha blending.
    /// - Parameters:
    ///   - pt: Icon size in point (pt).
    ///   - alpha: Icon alpha value.
    /// - Returns: A new icon image.n
    func icon(pt: CGFloat, alpha: CGFloat = 1) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: pt, height: pt), false, scale)
        let position = CGPoint(x: (pt - size.width) / 2, y: (pt - size.height) / 2)
        draw(at: position, blendMode: .normal, alpha: alpha)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}

class ShowVideoEditor: NSObject {
    weak var presentingViewController: UIViewController?
    // Keep a strong reference to saveVideoService
    private let saveVideoService = SaveVideoToRemoteURL()
    
    override init() {
        super.init()
        setupCustomIcons()
    }
    
    private func setupCustomIcons() {
        // Create a symbol configuration with scale variant large
        let config = UIImage.SymbolConfiguration(scale: .large)
        
        // Set up the image replacement closure
        IMGLY.bundleImageBlock = { imageName in
            // Return replacement images for the requested image name
            switch imageName {
            // Replace cancel, approve, and save icons with alpha 0.6
            case "imgly_icon_cancel_44pt":
                return UIImage(systemName: "multiply.circle.fill", withConfiguration: config)?.icon(pt: 44, alpha: 0.6)
            case "imgly_icon_approve_44pt":
                return UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)?.icon(pt: 44, alpha: 0.6)
            case "imgly_icon_save":
                return UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config)?.icon(pt: 44, alpha: 0.6)
                
            // Replace undo and redo icons
            case "imgly_icon_undo_48pt":
                return UIImage(systemName: "arrow.uturn.backward", withConfiguration: config)?.icon(pt: 48)
            case "imgly_icon_redo_48pt":
                return UIImage(systemName: "arrow.uturn.forward", withConfiguration: config)?.icon(pt: 48)
                
            // Replace play/pause and sound icons
            case "imgly_icon_play_48pt":
                return UIImage(systemName: "play.fill", withConfiguration: config)?.icon(pt: 48)
            case "imgly_icon_pause_48pt":
                return UIImage(systemName: "pause.fill", withConfiguration: config)?.icon(pt: 48)
            case "imgly_icon_sound_on_48pt":
                return UIImage(systemName: "speaker.wave.2.fill", withConfiguration: config)?.icon(pt: 48)
            case "imgly_icon_sound_off_48pt":
                return UIImage(systemName: "speaker.slash.fill", withConfiguration: config)?.icon(pt: 48)
                
            // Use default icon image for any other cases
            default:
                return nil
            }
        }
    }

    func showVideoEditor(with videoURL: URL) {
        saveVideoService.presentingViewController = self.presentingViewController
        
        // Create video from passed URL
        let video = VideoEditorSDK.Video(url: videoURL)
        
        let configuration = Configuration { builder in
            // Configure the `OverlayToolController` which lets the user
            // place overlays on top of the video.
            builder.configureOverlayToolController { options in
                // By default the editor has an initial overlay intensity of
                // 100% (1). For this example it only uses 50% (0.5).
                options.initialOverlayIntensity = 0.5
                
                // By default the editor shows a slider to let the user change
                // the intensity of an overlay. For this example this is disabled.
                // Thereby the overlays will always have an intensity of 50% (0.5)
                // since we applied this with the `initialOverlayIntensity`.
                options.showOverlayIntensitySlider = false
            }
            
            builder.theme = .dynamic
        }
        
        var videoEditor = VideoEditorSwiftUIView(video: video, configuration: configuration)

        videoEditor.dismissAction = {
            self.presentingViewController?.dismiss(animated: true, completion: nil)
        }

        videoEditor.saveVideoAction = { [weak self] result in
            guard let userId = Auth.auth().currentUser?.uid else {
                print("❌ No authenticated user")
                return
            }
            
            // Create video metadata
            let videoMetadata = [
                "authorId": userId,
                "createdAt": FieldValue.serverTimestamp(),
                "title": "Video \(UUID().uuidString.prefix(6))",
                "description": "Created on \(Date())",
                "status": "processing",
                "isDeleted": false
            ] as [String : Any]
            
            // Upload without metadata parameter since it's not supported yet
            self?.saveVideoService.uploadVideo(
                from: result.output.url,
                result: result
            )
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
    let configuration: Configuration
    
    @State private var showBirdAnimation = false
    
    var body: some View {
        ZStack {
            VideoEditor(video: video, configuration: configuration)
                .onDidSave { result in
                    print("📹 Received video at \(result.output.url.absoluteString)")
                    saveVideoAction?(result)
                    showBirdAnimation = true
                }
                .onDidCancel {
                    print("🚫 Editor cancelled")
                    dismissAction?()
                }
                .onDidFail { error in
                    print("❌ Editor failed: \(error.localizedDescription)")
                    dismissAction?()
                }
                .ignoresSafeArea()
            
            GraduationBirdAnimation(isShowing: $showBirdAnimation) {
                dismissAction?()
            }
        }
    }
}
