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
    @State private var videoURL: URL?
    @State private var vesdkPresented: Bool = false
    @State private var photoEditModel: PhotoEditModel?
    @State private var showBirdAnimation = false
    
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
            
            builder.theme = .dynamic
        }
    }()

    // MARK: - Body
    var body: some View {
        ZStack {
            Camera(configuration: configuration)
                .onDidCancel {
                    dismissAction?()
                }
                .onDidSave { result in
                    photoEditModel = result.model
                    if let url = result.url {
                        videoURL = url
                    }
                }
                .ignoresSafeArea()
                .fullScreenCover(isPresented: $vesdkPresented) {
                    dismissAction?()
                } content: {
                    if let url = videoURL {
                        MyVideoEditorViewWrapper(videoURL: url)
                            .onDisappear {
                                showBirdAnimation = true
                            }
                    }
                }
                .onChange(of: videoURL) { _ in
                    vesdkPresented = true
                }
            
            // Overlay the graduation bird animation
            GraduationBirdAnimation(isShowing: $showBirdAnimation) {
                // After animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismissAction?()
                }
            }
        }
    }
}
