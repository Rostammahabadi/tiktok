import SwiftUI
import AVKit
import FirebaseFirestore
import FirebaseStorage

struct VideoFeedView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @State private var currentIndex = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading && viewModel.videos.isEmpty {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading videos...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                } else if let error = viewModel.error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("Error loading videos")
                            .foregroundColor(.white)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else if viewModel.videos.isEmpty {
                    Text("No videos available")
                        .foregroundColor(.white)
                } else {
                    VerticalPager(pageCount: viewModel.videos.count, currentIndex: $currentIndex) {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                                VideoContainer(video: video, isActive: index == currentIndex)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            print("📱 VideoFeedView appeared, fetching initial videos...")
            viewModel.fetchVideos()
        }
        .onChange(of: currentIndex) { newIndex in
            print("📱 Current video index changed to: \(newIndex)")
            viewModel.loadMoreIfNeeded(currentIndex: newIndex)
        }
    }
}

struct VideoContainer: View {
    let video: VideoModel
    let isActive: Bool
    
    var body: some View {
        ZStack {
            if video.status == "completed" {
                VideoPlayerView(video: video, isActive: isActive)
            } else if video.status == "processing" {
                ProcessingView()
            } else if video.status == "failed" {
                FailedVideoView(error: video.error ?? "Unknown error")
            }
        }
    }
}

struct ProcessingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("Processing video...")
                .foregroundColor(.white)
                .padding(.top)
        }
    }
}

struct FailedVideoView: View {
    let error: String
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.white)
            Text("Failed to process video")
                .foregroundColor(.white)
            Text(error)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct VideoPlayerView: View {
    let video: VideoModel
    let isActive: Bool
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var playerItem: AVPlayerItem?
    @State private var observers: [NSKeyValueObservation] = []
    @State private var isUsingFallback = false
    @State private var isPlaying = false
    @State private var isReadyToPlay = false
    @State private var setupTask: Task<Void, Never>?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let error = error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Error: \(error.localizedDescription)")
                            .multilineTextAlignment(.center)
                            .padding()
                        if !isUsingFallback, video.originalUrl != nil {
                            Button("Try Original Video") {
                                isUsingFallback = true
                                setupTask?.cancel()
                                setupTask = Task {
                                    await setupPlayer(useOriginal: true)
                                }
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                    .foregroundColor(.white)
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else if let player = player {
                    ZStack {
                        CustomVideoPlayer(player: player)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        
                        // Play button overlay - only show when video is ready but not playing
                        if !isPlaying && isReadyToPlay {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .onTapGesture {
                        if isPlaying {
                            player.pause()
                            isPlaying = false
                        } else if isReadyToPlay {
                            player.play()
                            isPlaying = true
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                print("📱 Video became active")
                setupTask?.cancel()
                setupTask = Task {
                    await setupPlayer(useOriginal: false)
                }
            } else {
                print("📱 Video became inactive")
                // Cancel any ongoing setup
                setupTask?.cancel()
                setupTask = nil
                // Cleanup when video becomes inactive
                player?.pause()
                isPlaying = false
                // Remove all observers
                observers.forEach { $0.invalidate() }
                observers.removeAll()
                // Remove player item
                player?.replaceCurrentItem(with: nil)
                player = nil
                playerItem = nil
                isReadyToPlay = false
                isLoading = false
            }
        }
        .onAppear {
            print("📱 VideoPlayerView appeared")
            if isActive {
                setupTask?.cancel()
                setupTask = Task {
                    await setupPlayer(useOriginal: false)
                }
            }
        }
        .onDisappear {
            print("📱 VideoPlayerView disappeared")
            // Cancel any ongoing setup
            setupTask?.cancel()
            setupTask = nil
            // Cleanup on disappear
            player?.pause()
            isPlaying = false
            observers.forEach { $0.invalidate() }
            observers.removeAll()
            player?.replaceCurrentItem(with: nil)
            player = nil
            playerItem = nil
            isReadyToPlay = false
            isLoading = false
        }
    }
    
    private func setupPlayer(useOriginal: Bool) async {
        // Check if task is cancelled before starting
        guard !Task.isCancelled else {
            print("🚫 Setup cancelled before starting")
            return
        }
        
        // Clear previous state
        error = nil
        isLoading = true
        isReadyToPlay = false
        isPlaying = false
        player?.pause()
        player = nil
        
        do {
            if !useOriginal, let hlsPath = video.hlsPath, let segments = video.hlsSegments {
                print("🎬 Setting up HLS playback")
                print("📋 Manifest path: \(hlsPath)")
                
                // Get Storage references
                let storage = Storage.storage()
                let manifestRef = storage.reference().child(hlsPath)
                
                // First verify all segments exist
                print("🔍 Verifying HLS segments...")
                for segmentPath in segments {
                    // Check for cancellation before each segment
                    guard !Task.isCancelled else {
                        print("🚫 Setup cancelled during segment verification")
                        return
                    }
                    
                    let segmentRef = storage.reference().child(segmentPath)
                    _ = try await segmentRef.getMetadata()
                    print("✅ Verified segment: \(segmentPath)")
                }
                
                // Check for cancellation before getting manifest
                guard !Task.isCancelled else {
                    print("🚫 Setup cancelled before manifest download")
                    return
                }
                
                // Get manifest URL
                let manifestUrl = try await manifestRef.downloadURL()
                print("📄 Got manifest URL: \(manifestUrl)")
                
                // Create asset with HLS-specific options
                let asset = AVURLAsset(
                    url: manifestUrl,
                    options: [
                        "AVURLAssetHTTPHeaderFieldsKey": ["Accept": "application/x-mpegURL"],
                        "AVURLAssetOutOfBandMIMETypeKey": "application/x-mpegURL"
                    ]
                )
                
                // Check for cancellation before loading asset
                guard !Task.isCancelled else {
                    print("🚫 Setup cancelled before asset load")
                    return
                }
                
                // Load and validate HLS content
                try await asset.load(.tracks, .duration)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                print("🎥 Found \(tracks.count) video tracks")
                
                let playerItem = AVPlayerItem(asset: asset)
                let newPlayer = AVPlayer(playerItem: playerItem)
                
                // Add status observation
                let statusObservation = playerItem.observe(\.status) { item, _ in
                    if item.status == .readyToPlay {
                        print("✅ HLS video ready to play")
                        Task { @MainActor in
                            self.isReadyToPlay = true
                            if self.isActive {
                                self.isPlaying = true
                                newPlayer.play()
                            }
                        }
                    } else if item.status == .failed {
                        print("❌ HLS playback failed: \(item.error?.localizedDescription ?? "Unknown error")")
                    }
                }
                observers.append(statusObservation)
                
                // Monitor loaded ranges
                let timeRangeObservation = playerItem.observe(\.loadedTimeRanges) { item, _ in
                    guard let timeRange = item.loadedTimeRanges.first?.timeRangeValue else { return }
                    let start = timeRange.start.seconds
                    let duration = timeRange.duration.seconds
                    print("📊 Buffered: \(start) to \(start + duration) seconds")
                }
                observers.append(timeRangeObservation)
                
                // Monitor if playback is likely to keep up
                let playbackLikelyObservation = playerItem.observe(\.isPlaybackLikelyToKeepUp) { item, _ in
                    print("📊 Playback likely to keep up: \(item.isPlaybackLikelyToKeepUp)")
                }
                observers.append(playbackLikelyObservation)
                
                // Final cancellation check before updating UI
                guard !Task.isCancelled else {
                    print("🚫 Setup cancelled before player setup")
                    return
                }
                
                await MainActor.run {
                    self.player = newPlayer
                    self.isLoading = false
                }
                
                // Set up looping
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { [weak newPlayer] _ in
                    print("🔄 HLS video reached end, looping...")
                    newPlayer?.seek(to: .zero)
                    newPlayer?.play()
                }
            } else if let originalUrl = video.originalUrl {
                // Fallback to original video URL
                print("🎬 Using original video URL: \(originalUrl)")
                
                let asset = AVURLAsset(url: originalUrl)
                
                // Check for cancellation before loading asset
                guard !Task.isCancelled else {
                    print("🚫 Setup cancelled before asset load")
                    return
                }
                
                try await asset.load(.tracks, .duration)
                
                let playerItem = AVPlayerItem(asset: asset)
                let newPlayer = AVPlayer(playerItem: playerItem)
                
                // Add status observation
                let statusObservation = playerItem.observe(\.status) { item, _ in
                    if item.status == .readyToPlay {
                        print("✅ Original video ready to play")
                        Task { @MainActor in
                            self.isReadyToPlay = true
                            if self.isActive {
                                self.isPlaying = true
                                newPlayer.play()
                            }
                        }
                    }
                }
                observers.append(statusObservation)
                
                // Final cancellation check before updating UI
                guard !Task.isCancelled else {
                    print("🚫 Setup cancelled before player setup")
                    return
                }
                
                await MainActor.run {
                    self.player = newPlayer
                    self.isLoading = false
                }
                
                // Set up looping
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { [weak newPlayer] _ in
                    print("🔄 Original video reached end, looping...")
                    newPlayer?.seek(to: .zero)
                    newPlayer?.play()
                }
            }
        } catch {
            // Only update UI if not cancelled
            guard !Task.isCancelled else {
                print("🚫 Setup cancelled after error")
                return
            }
            
            print("❌ Error setting up player: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
}

struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

class VideoFeedViewModel: ObservableObject {
    @Published var videos: [VideoModel] = []
    @Published var isLoading = true
    @Published var error: Error?
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var lastDocument: DocumentSnapshot?
    private let batchSize = 2 // Load current and next video
    private var isFetching = false
    
    func fetchVideos() {
        print("🎬 Fetching videos...")
        isLoading = true
        
        var query = db.collection("videos")
            .whereField("status", isEqualTo: "completed")
            .whereField("type", isEqualTo: "hls")  // Only fetch HLS videos
            .order(by: "created_at", descending: true)
            .limit(to: batchSize)
        print("🔍 Querying Firestore collection 'videos' for HLS videos...")
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isFetching = false
            
            if let error = error {
                print("❌ Error fetching videos: \(error.localizedDescription)")
                self.error = error
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("⚠️ No HLS videos found")
                self.isLoading = false
                return
            }
            
            self.lastDocument = documents.last
            self.processDocuments(documents)
            self.isLoading = false
        }
    }
    
    func loadMoreIfNeeded(currentIndex: Int) {
        // If we're on the second-to-last video, load more
        if currentIndex >= videos.count - 2 {
            loadMore()
        }
    }
    
    private func loadMore() {
        guard !isFetching, let lastDocument = lastDocument else { return }
        print("🔄 Loading more HLS videos...")
        isFetching = true
        
        db.collection("videos")
            .whereField("status", isEqualTo: "completed")
            .whereField("type", isEqualTo: "hls")  // Only fetch HLS videos
            .order(by: "created_at", descending: true)
            .limit(to: batchSize)
            .start(afterDocument: lastDocument)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isFetching = false
                
                if let error = error {
                    print("❌ Error loading more videos: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("⚠️ No more HLS videos to load")
                    return
                }
                
                self.lastDocument = documents.last
                self.processDocuments(documents)
            }
    }
    
    private func processDocuments(_ documents: [QueryDocumentSnapshot]) {
        let newVideos = documents.compactMap { document -> VideoModel? in
            let data = document.data()
            print("🎥 Processing HLS video document: \(document.documentID)")
            
            // Get HLS path and parse for segments
            if let hlsPath = data["hlsPath"] as? String {
                print("🎯 HLS manifest path: \(hlsPath)")
                
                // Get the base folder path
                let hlsFolderPath = hlsPath.replacingOccurrences(of: "/output.m3u8", with: "")
                
                // Define expected segment paths
                let segmentPaths = (0...10).map { index in // Assuming max 10 segments
                    "\(hlsFolderPath)/segment\(String(format: "%03d", index)).ts"
                }
                print("🎬 Looking for segments in: \(hlsFolderPath)")
                print("📋 Expected segments:")
                segmentPaths.forEach { print("   - \($0)") }
                
                return VideoModel(
                    id: document.documentID,
                    hlsPath: hlsPath,
                    hlsSegments: segmentPaths,
                    hlsUrl: URL(string: data["hlsUrl"] as? String ?? ""),
                    originalUrl: URL(string: data["originalUrl"] as? String ?? ""),
                    status: data["status"] as? String ?? "completed",
                    error: nil
                )
            }
            
            // Fallback to original URL if no HLS
            if let originalUrl = URL(string: data["originalUrl"] as? String ?? "") {
                print("⚠️ No HLS path found, using original URL")
                return VideoModel(
                    id: document.documentID,
                    hlsPath: nil,
                    hlsSegments: nil,
                    hlsUrl: nil,
                    originalUrl: originalUrl,
                    status: data["status"] as? String ?? "completed",
                    error: nil
                )
            }
            
            print("❌ No valid URLs found for video")
            return nil
        }
        
        DispatchQueue.main.async {
            self.videos.append(contentsOf: newVideos)
            print("✅ Added \(newVideos.count) new videos. Total: \(self.videos.count)")
        }
    }
}

struct VideoModel: Identifiable {
    let id: String
    let hlsPath: String?      // Path to m3u8 manifest in Storage
    let hlsSegments: [String]? // List of segment paths
    let hlsUrl: URL?          // Pre-signed URL (fallback)
    let originalUrl: URL?
    let status: String
    let error: String?
}

struct HeartAnimation: View {
    let position: CGPoint
    @Binding var isAnimating: Bool
    
    var body: some View {
        Image(systemName: "heart.fill")
            .foregroundColor(.red)
            .font(.system(size: 30))
            .modifier(FloatingHearts(isAnimating: isAnimating, startPoint: position))
    }
}

struct FloatingHearts: ViewModifier {
    let isAnimating: Bool
    let startPoint: CGPoint
    @State private var hearts: [(offset: CGSize, scale: CGFloat, opacity: Double)] = []
    
    func body(content: Content) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                content
                    .offset(hearts.indices.contains(index) ? hearts[index].offset : .zero)
                    .scaleEffect(hearts.indices.contains(index) ? hearts[index].scale : 1)
                    .opacity(hearts.indices.contains(index) ? hearts[index].opacity : 0)
            }
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                animateHearts()
            }
        }
    }
    
    private func animateHearts() {
        hearts.removeAll()
        
        for index in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                let randomX = CGFloat.random(in: -50...50)
                let randomY = CGFloat.random(in: -150...(-100))
                hearts.append((
                    offset: CGSize(width: randomX, height: randomY),
                    scale: CGFloat.random(in: 0.5...1.5),
                    opacity: 1
                ))
                
                withAnimation(.easeOut(duration: 1.0)) {
                    let lastIndex = hearts.count - 1
                    if hearts.indices.contains(lastIndex) {
                        hearts[lastIndex].opacity = 0
                        hearts[lastIndex].offset.height -= 50
                    }
                }
            }
        }
    }
}

extension View {
    func onTapGesture(count: Int, perform action: @escaping (CGPoint) -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    action(value.location)
                }
        )
    }
}
