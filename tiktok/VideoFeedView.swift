import SwiftUI
import AVKit

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
    @StateObject private var viewModel = VideoViewModel()
    @State private var currentIndex = 0
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading videos...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
            } else if viewModel.videos.isEmpty {
                VStack {
                    Text("No videos available")
                        .foregroundColor(.white)
                    Button("Retry") {
                        print("🔄 Retrying video fetch...")
                        Task {
                            await viewModel.fetchVideos()
                        }
                    }
                }
            } else {
                VerticalPager(pageCount: viewModel.videos.count, currentIndex: $currentIndex) {
                    ForEach(viewModel.videos.indices, id: \.self) { index in
                        VideoPlayerView(video: viewModel.videos[index])
                    }
                }
            }
        }
        .ignoresSafeArea()
        .task {
            print("📱 VideoFeedView appeared, fetching videos...")
            await viewModel.fetchVideos()
        }
    }
    
    /// Prefetch the next couple of videos so they're ready when the user scrolls.
    private func prefetchAdjacentVideos(currentIndex: Int) {
        let adjacentIndices = [currentIndex + 1, currentIndex + 2]
        
        Task.detached(priority: .background) {
            for index in adjacentIndices {
                guard index < viewModel.videos.count else { continue }
                
                let video = viewModel.videos[index]
                guard let url = URL(string: video.videoURL) else { continue }
                
                // Check cache first
                if VideoCache.shared.getData(for: video.videoURL) == nil {
                    do {
                        let playerItem = CachingPlayerItem(url: url)
                        // Start preloading asset
                        try await playerItem.asset.load(.isPlayable)
                    } catch {
                        print("Error prefetching video at index \(index): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

struct VideoPlayerView: View {
    let video: Video
    @State private var player: AVPlayer?
    @State private var playerError: Error?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        print("▶️ Starting playback for video: \(video.videoURL)")
                        player.play()
                    }
                    .onDisappear {
                        print("⏸ Pausing playback for video: \(video.videoURL)")
                        player.pause()
                    }
            } else if playerError != nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Error loading video")
                        .padding()
                }
                .foregroundColor(.white)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading) {
                        Text(video.author)
                            .font(.headline)
                        Text(video.title)
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .padding()
                .foregroundColor(.white)
            }
        }
        .onAppear {
            print("🎥 Setting up player for URL: \(video.videoURL)")
            if let url = URL(string: video.videoURL) {
                print("✅ Valid URL created")
                let newPlayer = AVPlayer(url: url)
                newPlayer.automaticallyWaitsToMinimizeStalling = false
                
                // Add observer for player errors
                NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: newPlayer.currentItem, queue: .main) { notification in
                    if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                        print("❌ Player error: \(error.localizedDescription)")
                        self.playerError = error
                    }
                }
                
                self.player = newPlayer
            } else {
                print("❌ Invalid URL: \(video.videoURL)")
                self.playerError = NSError(domain: "VideoPlayerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
        }
        .onDisappear {
            print("🔄 Cleaning up player for video: \(video.videoURL)")
            player?.pause()
            player = nil
            NotificationCenter.default.removeObserver(self)
        }
    }
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
