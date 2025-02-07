import SwiftUI
import AVKit

struct VideoTrimmerView: View {
    let asset: AVAsset
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var currentTime: Double = 0
    @State private var thumbnails: [UIImage] = []
    @State private var player: AVPlayer?
    @State private var isDragging = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var videoUploader = VideoUploader()
    @State private var showingUploadProgress = false
    @State private var videoTitle = ""
    @State private var videoDescription = ""
    @State private var isLoading = true
    
    init(url: URL) {
        let urlAsset = AVURLAsset(url: url)
        self.asset = urlAsset
        _player = State(initialValue: AVPlayer(url: url))
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                VStack(spacing: 0) {
                    // Video preview
                    VideoPlayer(player: player)
                        .frame(height: UIScreen.main.bounds.height * 0.6)
                        .onChange(of: currentTime) { newValue in
                            player?.seek(to: CMTime(seconds: newValue, preferredTimescale: 600))
                        }
                    
                    // Trimmer interface
                    VStack {
                        // Time indicators
                        HStack {
                            Text(timeString(from: startTime))
                            Spacer()
                            Text(timeString(from: endTime - startTime))
                            Spacer()
                            Text(timeString(from: endTime))
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        
                        // Thumbnails scroll view with trim handles
                        ZStack(alignment: .leading) {
                            // Thumbnails
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    ForEach(thumbnails, id: \.self) { thumbnail in
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .frame(width: 50, height: 60)
                                            .clipped()
                                    }
                                }
                            }
                            .frame(height: 60)
                            
                            // Trim overlay
                            GeometryReader { geometry in
                                ZStack {
                                    // Left handle
                                    Rectangle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: startTime / endTime * geometry.size.width)
                                    
                                    // Right handle
                                    Rectangle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: (1 - endTime / CMTimeGetSeconds(asset.duration)) * geometry.size.width)
                                        .position(x: geometry.size.width, y: geometry.size.height / 2)
                                    
                                    // Trim area indicator
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(
                                            width: (endTime - startTime) / CMTimeGetSeconds(asset.duration) * geometry.size.width
                                        )
                                        .position(
                                            x: (startTime + (endTime - startTime) / 2) / CMTimeGetSeconds(asset.duration) * geometry.size.width,
                                            y: geometry.size.height / 2
                                        )
                                    
                                    // Drag handles
                                    HStack {
                                        // Left handle
                                        Rectangle()
                                            .fill(Color.white)
                                            .frame(width: 4, height: geometry.size.height)
                                            .position(x: startTime / CMTimeGetSeconds(asset.duration) * geometry.size.width, y: geometry.size.height / 2)
                                            .gesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        let newStart = max(0, min(endTime - 1, value.location.x / geometry.size.width * CMTimeGetSeconds(asset.duration)))
                                                        startTime = newStart
                                                        currentTime = newStart
                                                        isDragging = true
                                                    }
                                                    .onEnded { _ in
                                                        isDragging = false
                                                    }
                                            )
                                        
                                        Spacer()
                                        
                                        // Right handle
                                        Rectangle()
                                            .fill(Color.white)
                                            .frame(width: 4, height: geometry.size.height)
                                            .position(x: endTime / CMTimeGetSeconds(asset.duration) * geometry.size.width, y: geometry.size.height / 2)
                                            .gesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        let newEnd = max(startTime + 1, min(CMTimeGetSeconds(asset.duration), value.location.x / geometry.size.width * CMTimeGetSeconds(asset.duration)))
                                                        endTime = newEnd
                                                        currentTime = newEnd
                                                        isDragging = true
                                                    }
                                                    .onEnded { _ in
                                                        isDragging = false
                                                    }
                                            )
                                    }
                                }
                            }
                        }
                        .background(Color.black)
                        .cornerRadius(4)
                        
                        // Add title and description fields before the controls
                        VStack(spacing: 10) {
                            TextField("Video Title", text: $videoTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Video Description", text: $videoDescription)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // Controls
                        HStack {
                            Button("Cancel") {
                                dismiss()
                            }
                            .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("Done") {
                                Task {
                                    await trimVideo()
                                }
                            }
                            .foregroundColor(.white)
                        }
                        .padding()
                    }
                    .padding()
                    .background(Color.black)
                }
            }
            
            uploadOverlay
        }
        .task {
            // Load asset properties asynchronously
            do {
                try await asset.load(.duration)
                endTime = try await asset.load(.duration).seconds
                isLoading = false
                await generateThumbnails()
            } catch {
                print("Error loading asset: \(error)")
            }
        }
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func generateThumbnails() async {
        guard let duration = try? await asset.load(.duration).seconds else { return }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 100)
        
        let frameCount = 10
        let interval = duration / Double(frameCount)
        
        var times: [CMTime] = []
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
            times.append(time)
        }
        
        var images: [UIImage] = []
        for time in times {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                images.append(image)
            } catch {
                print("Error generating thumbnail: \(error)")
            }
        }
        
        await MainActor.run {
            self.thumbnails = images
        }
    }
    
    private func trimVideo() async {
        // Implement video trimming logic
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return
        }
        
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceVideoTrack = tracks.first else { return }
            
            let timeRange = CMTimeRange(
                start: CMTime(seconds: startTime, preferredTimescale: 600),
                end: CMTime(seconds: endTime, preferredTimescale: 600)
            )
            
            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
            
            // Export trimmed video
            if let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) {
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                
                await exportSession.export()
                
                switch exportSession.status {
                case .completed:
                    if let outputURL = exportSession.outputURL {
                        showingUploadProgress = true
                        do {
                            let videoURL = try await videoUploader.uploadVideo(
                                url: outputURL,
                                title: videoTitle,
                                description: videoDescription
                            )
                            print("Video uploaded successfully: \(videoURL)")
                            dismiss()
                        } catch {
                            print("Upload error: \(error.localizedDescription)")
                        }
                    }
                case .failed:
                    print("Failed to trim video: \(String(describing: exportSession.error))")
                default:
                    break
                }
            }
        } catch {
            print("Error trimming video: \(error)")
        }
    }
    
    // Add upload progress overlay
    var uploadOverlay: some View {
        Group {
            if showingUploadProgress && videoUploader.isUploading {
                ZStack {
                    Color.black.opacity(0.7)
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Uploading video... \(Int(videoUploader.uploadProgress * 100))%")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }
}
