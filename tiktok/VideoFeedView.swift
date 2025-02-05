import SwiftUI
import AVKit
import FirebaseFirestore
import FirebaseStorage

struct VerticalPager<Content: View>: View {
    let pageCount: Int
    @Binding var currentIndex: Int
    let content: Content
    
    init(pageCount: Int, currentIndex: Binding<Int>, @ViewBuilder content: () -> Content) {
        self.pageCount = pageCount
        self._currentIndex = currentIndex
        self.content = content()
        print("🔄 VerticalPager initialized with \(pageCount) pages")
    }
    
    @GestureState private var translation: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            LazyVStack(spacing: 0) {
                self.content.frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .offset(y: -CGFloat(self.currentIndex) * geometry.size.height)
            .offset(y: self.translation)
            .animation(.interactiveSpring(response: 0.3), value: currentIndex)
            .animation(.interactiveSpring(), value: translation)
            .gesture(
                DragGesture(minimumDistance: 1).updating(self.$translation) { value, state, _ in
                    state = value.translation.height
                }.onEnded { value in
                    let offset = -Int(value.translation.height)
                    if abs(offset) > 20 {
                        let newIndex = currentIndex + min(max(offset, -1), 1)
                        if newIndex >= 0 && newIndex < pageCount {
                            print("📱 Switching to video index: \(newIndex)")
                            self.currentIndex = newIndex
                        }
                    }
                }
            )
        }
    }
}

struct VideoFeedView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.videos.isEmpty {
                    Text("Loading videos...")
                        .foregroundColor(.white)
                        .frame(height: UIScreen.main.bounds.height)
                } else {
                    ForEach(viewModel.videos) { video in
                        if video.status == "completed" {
                            VideoPlayerView(video: video)
                                .frame(height: UIScreen.main.bounds.height)
                        } else if video.status == "processing" {
                            ProcessingView()
                                .frame(height: UIScreen.main.bounds.height)
                        } else if video.status == "failed" {
                            FailedVideoView(error: video.error ?? "Unknown error")
                                .frame(height: UIScreen.main.bounds.height)
                        }
                    }
                }
            }
        }
        .background(Color.black)
        .onAppear {
            print("📱 VideoFeedView appeared, fetching videos...")
            viewModel.fetchVideos()
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
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var playerItem: AVPlayerItem?
    @State private var observers: [NSKeyValueObservation] = []
    @State private var isUsingFallback = false
    
    var body: some View {
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
                            setupPlayer(useOriginal: true)
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
            } else {
                VideoPlayer(player: player)
                    .onDisappear {
                        print("📱 Video player disappearing, cleaning up resources")
                        player?.pause()
                        player = nil
                        playerItem = nil
                        observers.forEach { $0.invalidate() }
                        observers.removeAll()
                    }
            }
        }
        .onAppear {
            print("📱 VideoPlayerView appeared")
            setupPlayer(useOriginal: false)
        }
    }
    
    private func setupPlayer(useOriginal: Bool) {
        // Clear previous state
        error = nil
        isLoading = true
        player?.pause()
        player = nil
        playerItem = nil
        observers.forEach { $0.invalidate() }
        observers.removeAll()
        
        // Determine which URL to use
        let videoUrl: URL?
        if useOriginal {
            videoUrl = video.originalUrl
            print("🎬 Using original video URL")
        } else {
            videoUrl = video.hlsUrl
            print("🎬 Using HLS URL")
        }
        
        guard let url = videoUrl else {
            print("❌ No valid URL available")
            error = NSError(domain: "VideoPlayer", code: -1, 
                          userInfo: [NSLocalizedDescriptionKey: "No valid video URL available"])
            isLoading = false
            return
        }
        
        print("🎬 Setting up player for URL: \(url)")
        print("🔍 URL scheme: \(url.scheme ?? "none")")
        print("🔍 URL host: \(url.host ?? "none")")
        print("🔍 URL path: \(url.path)")
        
        // Create an AVURLAsset with specific options for HLS
        let assetOptions = [AVURLAssetAllowsExpensiveNetworkAccessKey: true]
        let asset = AVURLAsset(url: url, options: assetOptions)
        print("📦 Created AVURLAsset")
        
        // Load asset properties asynchronously
        Task {
            do {
                print("🔄 Loading asset properties...")
                
                // Load asset properties
                try await asset.load(.tracks, .duration)
                let duration = asset.duration
                print("⏱️ Asset duration: \(duration.seconds) seconds")
                print("🎬 Number of tracks: \(asset.tracks.count)")
                
                // Print track information
                for track in asset.tracks {
                    print("🎯 Track: \(track.mediaType.rawValue), enabled: \(track.isEnabled)")
                }
                
                // Create player item with specific options
                let playerItem = AVPlayerItem(asset: asset)
                playerItem.preferredForwardBufferDuration = 5 // Buffer up to 5 seconds
                self.playerItem = playerItem
                
                // Add KVO observers using modern API
                let statusObserver = playerItem.observe(\.status) { item, _ in
                    print("🔄 Player item status changed to: \(item.status.rawValue)")
                    if item.status == .failed {
                        print("❌ Player item failed: \(String(describing: item.error))")
                        if let error = item.error as NSError? {
                            print("❌ Error domain: \(error.domain)")
                            print("❌ Error code: \(error.code)")
                            print("❌ Error description: \(error.localizedDescription)")
                            print("❌ Error user info: \(error.userInfo)")
                            
                            // Check for specific error logs
                            if let errorLog = item.errorLog() {
                                print("📝 Error Log:")
                                for event in errorLog.events {
                                    print("  - \(event.date): \(event.errorComment ?? "No comment") (Error code: \(event.errorStatusCode))")
                                }
                            }
                            
                            // Check for access log
                            if let accessLog = item.accessLog() {
                                print("📝 Access Log:")
                                for event in accessLog.events {
                                    if let uri = event.uri {
                                        print("  - URI: \(uri)")
                                    }
                                    print("    Bytes transferred: \(event.numberOfBytesTransferred)")
                                    print("    Indicated bitrate: \(event.indicatedBitrate)")
                                    print("    Observed bitrate: \(event.observedBitrate)")
                                    if let serverAddress = event.serverAddress {
                                        print("    Server: \(serverAddress)")
                                    }
                                    if event.numberOfServerAddressChanges > 0 {
                                        print("    Server changes: \(event.numberOfServerAddressChanges)")
                                    }
                                    if let startDate = event.playbackStartDate {
                                        print("    Start date: \(startDate)")
                                    }
                                }
                            }
                        }
                        self.error = item.error
                    }
                }
                observers.append(statusObserver)
                
                let bufferEmptyObserver = playerItem.observe(\.isPlaybackBufferEmpty) { item, _ in
                    print("📊 Playback buffer empty: \(item.isPlaybackBufferEmpty)")
                }
                observers.append(bufferEmptyObserver)
                
                let bufferFullObserver = playerItem.observe(\.isPlaybackBufferFull) { item, _ in
                    print("📊 Playback buffer full: \(item.isPlaybackBufferFull)")
                }
                observers.append(bufferFullObserver)
                
                let keepUpObserver = playerItem.observe(\.isPlaybackLikelyToKeepUp) { item, _ in
                    print("📊 Playback likely to keep up: \(item.isPlaybackLikelyToKeepUp)")
                }
                observers.append(keepUpObserver)
                
                // Create and configure player
                let player = AVPlayer(playerItem: playerItem)
                player.automaticallyWaitsToMinimizeStalling = true
                player.allowsExternalPlayback = true
                
                // Add periodic time observer for debugging
                let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                    print("▶️ Playback time: \(time.seconds) seconds")
                    if let error = playerItem.error {
                        print("❌ PlayerItem error during playback: \(error.localizedDescription)")
                    }
                }
                
                await MainActor.run {
                    self.player = player
                    self.isLoading = false
                    print("▶️ Starting playback")
                    player.play()
                }
                
            } catch {
                print("❌ Error setting up player: \(error.localizedDescription)")
                if let assetError = error as? AVError {
                    print("❌ AVError code: \(assetError.code.rawValue)")
                }
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

class VideoFeedViewModel: ObservableObject {
    @Published var videos: [VideoModel] = []
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    func fetchVideos() {
        print("🔍 Starting to fetch videos...")
        
        db.collection("videos")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching videos: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents found")
                    return
                }
                
                print("📄 Found \(documents.count) video documents")
                
                self?.videos = documents.compactMap { document -> VideoModel? in
                    let data = document.data()
                    print("🎥 Processing video document: \(document.documentID)")
                    
                    // Check video status
                    let status = data["status"] as? String ?? "unknown"
                    print("📊 Video status: \(status)")
                    
                    // Get both URLs
                    var hlsUrl: URL?
                    var originalUrl: URL?
                    
                    if let hlsUrlString = data["hlsUrl"] as? String {
                        hlsUrl = URL(string: hlsUrlString)
                        print("🎯 HLS URL available: \(hlsUrlString)")
                    }
                    
                    if let originalUrlString = data["originalUrl"] as? String {
                        originalUrl = URL(string: originalUrlString)
                        print("🎯 Original URL available: \(originalUrlString)")
                    }
                    
                    // Return nil if neither URL is available
                    guard hlsUrl != nil || originalUrl != nil else {
                        print("❌ No valid URLs found for video")
                        return nil
                    }
                    
                    return VideoModel(
                        id: document.documentID,
                        hlsUrl: hlsUrl,
                        originalUrl: originalUrl,
                        status: status,
                        error: data["error"] as? String
                    )
                }
                
                print("✅ Processed \(self?.videos.count ?? 0) videos")
            }
    }
}

struct VideoModel: Identifiable {
    let id: String
    let hlsUrl: URL?
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
