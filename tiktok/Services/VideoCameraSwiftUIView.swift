import SwiftUI
import VideoEditorSDK

struct VideoCameraSwiftUIView: View {
  // The action to dismiss the view.
  internal var dismissAction: (() -> Void)?

  // Create a `Video` from a URL to an image in the app bundle.
    @State private var video: VideoEditorSDK.Video?

  // Create a variable indicating whether the editor should be presented.
  @State private var vesdkPresented: Bool = false

  // The `PhotoEditModel` that preserves the selected filters from the camera.
  @State private var photoEditModel: PhotoEditModel?

  // Create a `Configuration` object.
  private let configuration = Configuration { builder in
    builder.configureCameraViewController { options in
      // Since we are only using VE.SDK, the camera
      // should only allow to record/select videos.
      options.allowedRecordingModes = [.video]

      // By default the camera does not show a cancel button,
      // so that it can be embedded into any other view. But since it is
      // presented modally here, a cancel button should be visible.
      options.showCancelButton = true
    }
  }

  // The body of the View.
  var body: some View {
    // Create a `Camera`.
    Camera(configuration: configuration)
      .onDidCancel {
        // The user tapped on the cancel button within the camera. Dismissing the view.
        dismissAction?()
      }
      .onDidSave { result in
        // The user has recorded or selected a video.
        photoEditModel = result.model

        // The `VideoEditorResult.url` argument will contain the url of the video.
        if let url = result.url {
            video = VideoEditorSDK.Video(url: url)
        }
      }
      // In order for the camera to fill out the whole screen it needs
      // to ignore the safe area.
      .ignoresSafeArea()
      .fullScreenCover(isPresented: $vesdkPresented) {
        dismissAction?()
      } content: {
        if let video = video {
          // Create a `VideoEditor`.
          VideoEditor(video: video, configuration: configuration, photoEditModel: photoEditModel)
            .onDidSave { result in
              // The user exported a new video successfully and the newly generated video is located at `result.output.url` of the returned `VideoEditorResult`. Dismissing the editor.
              print("Received video at \(result.output.url.absoluteString)")
              dismissAction?()
            }
            .onDidCancel {
              // The user tapped on the cancel button within the editor. Dismissing the editor.
              dismissAction?()
            }
            .onDidFail { error in
              // There was an error generating the video.
              print("Editor finished with error: \(error.localizedDescription)")
              // Dismissing the editor.
              dismissAction?()
            }
            // In order for the video editor to fill out the whole screen it needs
            // to ignore the safe area.
            .ignoresSafeArea()
        }
      }
      // Listen to changes of the video in order to present
      // the editor.
      .onChange(of: video) { _ in
        vesdkPresented = true
      }
  }
}
