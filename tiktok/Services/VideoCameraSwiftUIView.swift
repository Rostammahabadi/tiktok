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
    func icon(pt: CGFloat, alpha: CGFloat = 1) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: pt, height: pt), false, scale)
        let position = CGPoint(x: (pt - size.width) / 2, y: (pt - size.height) / 2)
        draw(at: position, blendMode: .normal, alpha: alpha)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}

struct VideoCameraSwiftUIView: View {
    // MARK: - Properties
    internal var dismissAction: (() -> Void)?
    @State private var video: VideoEditorSDK.Video?
    @State private var vesdkPresented: Bool = false
    @State private var photoEditModel: PhotoEditModel?
    private let saveVideoService = SaveVideoToRemoteURL()
    
    // MARK: - Configuration
    private let configuration: Configuration = {
        // Set up custom icons
        let config = UIImage.SymbolConfiguration(scale: .large)
        IMGLY.bundleImageBlock = { imageName in
            switch imageName {
            case "imgly_icon_cancel_44pt":
                return UIImage(systemName: "multiply.circle.fill", withConfiguration: config)?.icon(pt: 44, alpha: 0.6)
            case "imgly_icon_approve_44pt":
                return UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)?.icon(pt: 44, alpha: 0.6)
            case "imgly_icon_save":
                return UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config)?.icon(pt: 44, alpha: 0.6)
            case "imgly_icon_undo_48pt":
                return UIImage(systemName: "arrow.uturn.backward", withConfiguration: config)?.icon(pt: 48)
            case "imgly_icon_redo_48pt":
                return UIImage(systemName: "arrow.uturn.forward", withConfiguration: config)?.icon(pt: 48)
            case "imgly_icon_play_48pt":
                return UIImage(systemName: "play.fill", withConfiguration: config)?.icon(pt: 48)
            case "imgly_icon_pause_48pt":
                return UIImage(systemName: "pause.fill", withConfiguration: config)?.icon(pt: 48)
            case "imgly_icon_sound_on_48pt":
                return UIImage(systemName: "speaker.wave.2.fill", withConfiguration: config)?.icon(pt: 48)
            case "imgly_icon_sound_off_48pt":
                return UIImage(systemName: "speaker.slash.fill", withConfiguration: config)?.icon(pt: 48)
            default:
                return nil
            }
        }
        
        return Configuration { builder in
            // Configure camera
            builder.configureCameraViewController { options in
                options.allowedRecordingModes = [.video]
                options.showCancelButton = true
            }
            
            // Configure overlay tool
            builder.configureOverlayToolController { options in
                options.initialOverlayIntensity = 0.5
                options.showOverlayIntensitySlider = false
            }
            
            builder.theme = .dynamic
        }
    }()

    // MARK: - Body
    var body: some View {
        Camera(configuration: configuration)
            .onDidCancel {
                dismissAction?()
            }
            .onDidSave { result in
                photoEditModel = result.model
                if let url = result.url {
                    video = VideoEditorSDK.Video(url: url)
                }
            }
            .ignoresSafeArea()
            .fullScreenCover(isPresented: $vesdkPresented) {
                dismissAction?()
            } content: {
                if let video = video {
                    VideoEditor(video: video, configuration: configuration, photoEditModel: photoEditModel)
                        .onDidSave { result in
                            handleVideoSave(result)
                        }
                        .onDidCancel {
                            dismissAction?()
                        }
                        .onDidFail { error in
                            print("Editor failed with error: \(error.localizedDescription)")
                            dismissAction?()
                        }
                        .ignoresSafeArea()
                }
            }
            .onChange(of: video) { _ in
                vesdkPresented = true
            }
    }
    
    // MARK: - Private Methods
    private func handleVideoSave(_ result: VideoEditorResult) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            dismissAction?()
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
        
        // Upload video
        saveVideoService.uploadVideo(
            from: result.output.url,
            result: result
        )
        
        print("📹 Received video at \(result.output.url.absoluteString)")
        dismissAction?()
    }
}
