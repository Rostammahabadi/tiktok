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
                                Task {
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
                        
                        // Play button overlay
                        if !isPlaying {
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
                        } else {
                            player.play()
                        }
                        isPlaying.toggle()
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                print("📱 Video became active")
                player?.seek(to: .zero)
                player?.play()
                isPlaying = true
            } else {
                print("📱 Video became inactive")
                player?.pause()
                isPlaying = false
            }
        }
        .onAppear {
            print("📱 VideoPlayerView appeared")
            Task {
                await setupPlayer(useOriginal: false)
            }
        }
    }
    
    private func setupPlayer(useOriginal: Bool) async {
        // Clear previous state
        error = nil
        isLoading = true
        player?.pause()
        player = nil
        
        do {
            let videoUrl = useOriginal ? video.originalUrl?.absoluteString : video.hlsUrl?.absoluteString
            guard let url = URL(string: videoUrl ?? "") else {
                throw NSError(domain: "VideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
            let asset = AVURLAsset(url: url)
            
            // Load required asset properties asynchronously
            try await asset.load(.tracks, .duration, .preferredTransform)
            
            let playerItem = AVPlayerItem(asset: asset)
            let newPlayer = AVPlayer(playerItem: playerItem)
            
            await MainActor.run {
                self.player = newPlayer
                self.isLoading = false
            }
            
            // Set up player
            newPlayer.actionAtItemEnd = .none
            newPlayer.play()
            
            // Add observer for playback ended
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak newPlayer] _ in
                newPlayer?.seek(to: .zero)
                newPlayer?.play()
            }
        } catch {
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
