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
                    .scaleEffect(1.5)
            } else if let player = player {
                VideoPlayer(player: player)
                    .onDisappear {
                        print("📱 Video player disappearing, cleaning up resources")
                        player.pause()
                        observers.forEach { $0.invalidate() }
                        observers.removeAll()
                    }
            }
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                print("📱 Video became active")
                player?.seek(to: .zero)
                player?.play()
            } else {
                print("📱 Video became inactive")
                player?.pause()
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
    @Published var isLoading = true
    @Published var error: Error?
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var lastDocument: DocumentSnapshot?
    private let batchSize = 2 // Load current and next video
    private var isFetching = false
    
    func fetchVideos() {
        guard !isFetching else { return }
        print("🔍 Starting to fetch videos...")
        isLoading = true
        isFetching = true
        
        var query = db.collection("videos")
            .whereField("status", isEqualTo: "completed")
            .order(by: "createdAt", descending: true)
            .limit(to: batchSize)
        
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
                print("⚠️ No documents found")
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
        print("🔄 Loading more videos...")
        isFetching = true
        
        db.collection("videos")
            .whereField("status", isEqualTo: "completed")
            .order(by: "createdAt", descending: true)
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
                    print("⚠️ No more videos to load")
                    return
                }
                
                self.lastDocument = documents.last
                self.processDocuments(documents)
            }
    }
    
    private func processDocuments(_ documents: [QueryDocumentSnapshot]) {
        let newVideos = documents.compactMap { document -> VideoModel? in
            let data = document.data()
            print("🎥 Processing video document: \(document.documentID)")
            
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
            
            guard hlsUrl != nil || originalUrl != nil else {
                print("❌ No valid URLs found for video")
                return nil
            }
            
            return VideoModel(
                id: document.documentID,
                hlsUrl: hlsUrl,
                originalUrl: originalUrl,
                status: "completed",
                error: nil
            )
        }
        
        DispatchQueue.main.async {
            self.videos.append(contentsOf: newVideos)
            print("✅ Added \(newVideos.count) new videos. Total: \(self.videos.count)")
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
