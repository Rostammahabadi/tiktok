import SwiftUI
import FirebaseAuth
import AVKit

struct TeacherProfileView: View {
    @State private var selectedTab = 0
    @Binding var isLoggedIn: Bool
    @StateObject private var videoViewModel = VideoViewModel()
    @State private var isLoading = false
    @State private var selectedVideo: Video?
    @State private var isVideoPlayerPresented = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    VStack {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(Theme.accentColor)
                        
                        Text("Jane Smith")
                            .font(Theme.titleFont)
                            .foregroundColor(Theme.accentColor)
                        
                        Text("Math Teacher | 10 years experience")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textColor.opacity(0.8))
                    }
                    .padding()
                    
                    // Tab view for videos and about
                    Picker("", selection: $selectedTab) {
                        Text("Videos").tag(0)
                        Text("About").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if selectedTab == 0 {
                        // Videos grid
                        if videoViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                        } else if videoViewModel.userVideos.isEmpty {
                            Text("No videos yet")
                                .foregroundColor(Theme.textColor.opacity(0.6))
                                .padding()
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(videoViewModel.userVideos) { video in
                                    VideoThumbnail(video: video)
                                        .frame(maxWidth: .infinity)
                                        .onTapGesture {
                                            selectedVideo = video
                                            isVideoPlayerPresented = true
                                        }
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                    } else {
                        // About section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("About Me")
                                .font(Theme.headlineFont)
                                .foregroundColor(Theme.textColor)
                            
                            Text("I'm passionate about making math accessible and fun for all students. With 10 years of teaching experience, I specialize in creating engaging video content to supplement classroom learning.")
                                .font(Theme.bodyFont)
                                .foregroundColor(Theme.textColor.opacity(0.8))
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: logout) {
                        Text("Logout")
                            .foregroundColor(Theme.accentColor)
                    }
                }
            }
            .task {
                await videoViewModel.fetchUserVideos()
            }
            .refreshable {
                await videoViewModel.fetchUserVideos()
            }
            .sheet(isPresented: $isVideoPlayerPresented) {
                videoPlayerSheet
            }
        }
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    var videoPlayerSheet: some View {
        Group {
            if let video = selectedVideo {
                VideoPlayerSheet(video: video)
            }
        }
    }
}

struct VideoThumbnail: View {
    let video: Video
    @State private var thumbnail: Image?
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                if let thumbnail = thumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width/2 - 15, height: (UIScreen.main.bounds.width/2 - 15) * 3/4)
                        .clipped()
                } else if isLoading {
                    ProgressView()
                        .frame(width: UIScreen.main.bounds.width/2 - 15, height: (UIScreen.main.bounds.width/2 - 15) * 3/4)
                        .background(Color(uiColor: .secondarySystemBackground))
                } else {
                    // Fallback thumbnail or error state
                    Rectangle()
                        .foregroundColor(Color(uiColor: .secondarySystemBackground))
                        .frame(width: UIScreen.main.bounds.width/2 - 15, height: (UIScreen.main.bounds.width/2 - 15) * 3/4)
                        .overlay(
                            Group {
                                if loadError {
                                    Image(systemName: "photo.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(.gray)
                                } else {
                                    Image(systemName: "play.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.primary)
                                }
                            }
                        )
                }
            }
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(video.views) views")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1, y: 1)
        .padding(.bottom, 4)
        .task {
            isLoading = true
            loadError = false
            if let thumbnail = await video.loadThumbnail() {
                self.thumbnail = thumbnail
                isLoading = false
            } else {
                loadError = true
                isLoading = false
            }
        }
    }
}

struct VideoPlayerSheet: View {
    let video: Video
    @Environment(\.presentationMode) var presentationMode
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let player = player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            VStack {
                HStack {
                    Button(action: {
                        player?.pause()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding()
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupPlayer() {
        guard let url = URL(string: video.videoURL) else {
            error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
            isLoading = false
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        // Observe when the item is ready to play
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        
        self.player = newPlayer
        
        // Start playing when ready
        playerItem.asset.loadValuesAsynchronously(forKeys: ["playable"]) {
            DispatchQueue.main.async {
                self.isLoading = false
                newPlayer.play()
            }
        }
    }
}
