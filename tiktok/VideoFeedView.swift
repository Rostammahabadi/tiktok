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
        VerticalPager(pageCount: viewModel.videos.count, currentIndex: $currentIndex) {
            ForEach(viewModel.videos.indices, id: \.self) { index in
                FullScreenVideoCard(video: viewModel.videos[index])
                    .onAppear {
                        prefetchAdjacentVideos(currentIndex: index)
                    }
            }
        }
        .ignoresSafeArea()
        .task {
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

struct FullScreenVideoCard: View {
    let video: Video
    @State private var isLiked = false
    @State private var showLikeAnimation = false
    @State private var tapLocation: CGPoint = .zero
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            // Video player
            if let player = player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black // Loading placeholder
            }
            
            // Overlay content
            VStack {
                Spacer()
                
                HStack {
                    // Video info
                    VStack(alignment: .leading) {
                        Text(video.author)
                            .font(.headline)
                        Text(video.title)
                            .font(.subheadline)
                        Text(video.description)
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 20) {
                        // Like button
                        Button(action: { toggleLike() }) {
                            VStack {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 30))
                                    .foregroundColor(isLiked ? .red : .white)
                                Text("24.5K")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Comment button
                        Button(action: {}) {
                            VStack {
                                Image(systemName: "bubble.right")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                Text("1.2K")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Share button
                        Button(action: {}) {
                            VStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                Text("Share")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.trailing)
                }
                .padding(.bottom, 50)
            }
            .padding(.bottom, 30)
            
            // Like animation
            HeartAnimation(position: tapLocation, isAnimating: $showLikeAnimation)
        }
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupVideo() {
        guard let url = URL(string: video.videoURL) else { return }
        let cacheKey = video.videoURL
        
        // Check cache first
        if let cachedData = VideoCache.shared.getData(for: cacheKey),
           let playerItem = CachingPlayerItem(data: cachedData, url: url) {
            self.player = AVPlayer(playerItem: playerItem)
        } else {
            // Create caching player item for uncached video
            let playerItem = CachingPlayerItem(url: url)
            self.player = AVPlayer(playerItem: playerItem)
        }
        
        // Loop video playback
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem,
                                               queue: .main) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
        player?.play()
    }
    
    private func toggleLike() {
        if !isLiked {
            isLiked = true
            showLikeAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showLikeAnimation = false
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

