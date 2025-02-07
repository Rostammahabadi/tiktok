import SwiftUI
import FirebaseAuth
import AVKit

class ProjectViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    
    func fetchProjects() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            projects = try await ProjectService.shared.fetchUserProjects()
        } catch {
            print("❌ Error fetching projects: \(error.localizedDescription)")
        }
    }
}

struct TeacherProfileView: View {
    @State private var selectedTab = 0
    @Binding var isLoggedIn: Bool
    @StateObject private var projectViewModel = ProjectViewModel()
    @State private var isLoading = false
    @State private var selectedProject: Project?
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
                    
                    // Tab view for projects, videos and about
                    Picker("", selection: $selectedTab) {
                        Text("Projects").tag(0)
                        Text("About").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if selectedTab == 0 {
                        // Projects grid
                        if projectViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                        } else if projectViewModel.projects.isEmpty {
                            Text("No projects yet")
                                .foregroundColor(Theme.textColor.opacity(0.6))
                                .padding()
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(projectViewModel.projects) { project in
                                    ProjectThumbnail(project: project)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedProject = project
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
                await projectViewModel.fetchProjects()
            }
            .refreshable {
                await projectViewModel.fetchProjects()
            }
            .sheet(isPresented: $isVideoPlayerPresented) {
                if let video = selectedVideo {
                    VideoPlayerSheet(video: video)
                } else if let project = selectedProject {
                    // Add project player sheet here
                }
            }
        }
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }
}

struct ProjectThumbnail: View {
    let project: Project
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if let thumbnailImage = thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .frame(height: 150)
            } else {
                Image(systemName: "video.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
                    .foregroundColor(Theme.accentColor.opacity(0.5))
            }
            
            Text(project.title)
                .font(Theme.bodyFont)
                .foregroundColor(Theme.textColor)
                .lineLimit(1)
                .padding(.vertical, 5)
        }
        .background(Theme.backgroundColor)
        .cornerRadius(10)
        .shadow(radius: 3)
        .contextMenu {
            Button {
                // Edit action will be added later
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        guard let thumbnailUrlString = project.thumbnailUrl,
              let thumbnailUrl = URL(string: thumbnailUrlString) else {
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: thumbnailUrl)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    thumbnailImage = image
                }
            }
        } catch {
            print("❌ Error loading thumbnail: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

struct VideoGridView: View {
    @StateObject private var videoViewModel = VideoViewModel()
    @State private var selectedVideo: Video?
    @State private var isVideoPlayerPresented = false
    
    var body: some View {
        VStack {
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
                        VideoThumbnail(video: video, videoViewModel: videoViewModel)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVideo = video
                                isVideoPlayerPresented = true
                            }
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .task {
            await videoViewModel.fetchUserVideos()
        }
        .refreshable {
            await videoViewModel.fetchUserVideos()
        }
        .sheet(isPresented: $isVideoPlayerPresented) {
            if let video = selectedVideo {
                VideoPlayerSheet(video: video)
            }
        }
    }
}

struct VideoThumbnail: View {
    let video: Video
    let videoViewModel: VideoViewModel
    @State private var thumbnail: Image?
    @State private var isLoading = true
    @State private var loadError = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                if let thumbnail = thumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width/2 - 15, height: (UIScreen.main.bounds.width/2 - 15) * 3/4)
                        .clipped()
                        .overlay(alignment: .topTrailing) {
                            // Delete button
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                    .padding(8)
                            }
                            .zIndex(1) // Ensure delete button is above other content
                        }
                        .contextMenu {
                            Button {
                                // Edit action will be added later
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
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
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1, y: 1)
        .padding(.vertical, 4) // Changed from .bottom to .vertical for consistent spacing
        .alert("Delete Video", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await videoViewModel.deleteVideo(video)
                }
            }
        } message: {
            Text("Are you sure you want to delete this video? This action cannot be undone.")
        }
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
        
        let asset = AVURLAsset(url: url)
        
        Task {
            do {
                // Load asset properties
                try await asset.load(.tracks, .duration)
                
                // Create player item and set up player
                let playerItem = AVPlayerItem(asset: asset)
                let newPlayer = AVPlayer(playerItem: playerItem)
                
                // Observe when the item is ready to play
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
                    newPlayer.seek(to: .zero)
                    newPlayer.play()
                }
                
                await MainActor.run {
                    self.player = newPlayer
                    self.isLoading = false
                    newPlayer.play()
                }
            } catch {
                print("❌ Error setting up player: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}
