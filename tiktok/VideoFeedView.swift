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
                            VideoPlayerView(url: video.hlsURL)
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
    let url: URL
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        ZStack {
            if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Error: \(error.localizedDescription)")
                }
                .foregroundColor(.white)
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                VideoPlayer(player: player)
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        print("🎬 Setting up player for URL: \(url)")
        
        // Create an AVPlayerItem with specific options for HLS
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Set up player
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = false
        
        // Add observer for player status
        NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: .main) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ Player error: \(error.localizedDescription)")
                self.error = error
            }
        }
        
        // Monitor player item status
        Task {
            do {
                try await playerItem.asset.load(.isPlayable)
                if playerItem.asset.isPlayable {
                    await MainActor.run {
                        self.player = player
                        self.isLoading = false
                        player.play()
                    }
                } else {
                    throw NSError(domain: "VideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video is not playable"])
                }
            } catch {
                print("❌ Error loading video asset: \(error.localizedDescription)")
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
        
        // Listen for all video documents
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
                
                Task {
                    var newVideos: [VideoModel] = []
                    
                    for document in documents {
                        let data = document.data()
                        print("📝 Processing document: \(document.documentID)")
                        print("📄 Document data: \(data)")
                        
                        let status = data["status"] as? String ?? "unknown"
                        var videoURL: URL?
                        
                        // Try HLS URL first
                        if status == "completed",
                           let hlsPath = data["hlsPath"] as? String {
                            do {
                                let storageRef = self?.storage.reference().child(hlsPath)
                                videoURL = try await storageRef?.downloadURL()
                                print("✅ Got HLS URL: \(videoURL?.absoluteString ?? "")")
                            } catch {
                                print("⚠️ Couldn't get HLS URL: \(error.localizedDescription)")
                            }
                        }
                        
                        // Fallback to original URL if HLS isn't available
                        if videoURL == nil,
                           let originalUrlString = data["originalUrl"] as? String,
                           let url = URL(string: originalUrlString) {
                            videoURL = url
                            print("📼 Using original URL: \(url)")
                        }
                        
                        if let finalURL = videoURL {
                            let video = VideoModel(
                                id: document.documentID,
                                hlsURL: finalURL,
                                status: status,
                                error: data["error"] as? String
                            )
                            newVideos.append(video)
                        } else {
                            print("❌ No valid URL found for video: \(document.documentID)")
                        }
                    }
                    
                    await MainActor.run {
                        print("📱 Updating UI with \(newVideos.count) videos")
                        self?.videos = newVideos
                    }
                }
            }
    }
}

struct VideoModel: Identifiable {
    let id: String
    let hlsURL: URL
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
