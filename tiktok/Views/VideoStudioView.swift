import SwiftUI
import VideoEditorSDK
import ImglyKit
import AVFoundation
import PhotosUI

struct VideoStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPhotoPicker = true
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Group {
            if let videoURL = videoURL {
                // Only create video editor if we have a valid URL
                let video = ImglyKit.Video(url: videoURL)
                VideoEditor(video: video)
                    .onDidSave { result in
                        print("runing the result from onDidSave")
                        print("Received video at \(result.output.url.absoluteString)")
                        dismiss()
                    }
                    .onDidCancel {
                        print("cancelling")
                        dismiss()
                    }
                    .onDidFail { error in
                        print("Editor finished with error: \(error.localizedDescription)")
                        dismiss()
                    }
                    .ignoresSafeArea()
            } else {
                // Show photo picker if no video is selected
                PhotosPicker(selection: $selectedItem,
                           matching: .videos,
                           photoLibrary: .shared()) {
                    VStack {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 40))
                        Text("Select Video")
                            .font(.headline)
                    }
                    .foregroundColor(.blue)
                }
                .onChange(of: selectedItem) { newItem in
                    if let newItem = newItem {
                        loadVideo(from: newItem)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadVideo(from item: PhotosPickerItem) {
        Task {
            do {
                guard let videoURL = try await item.loadTransferable(type: URL.self) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load video URL"])
                }
                
                // Verify the video is valid
                let asset = AVAsset(url: videoURL)
                let tracks = try await asset.load(.tracks)
                guard !tracks.isEmpty else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video file"])
                }
                
                await MainActor.run {
                    self.videoURL = videoURL
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    VideoStudioView()
}
