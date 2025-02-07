import SwiftUI
import FirebaseAuth
import AVKit

class ProjectViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    
    func fetchProjects() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let fetchedProjects = try await ProjectService.shared.fetchUserProjects()
            await MainActor.run {
                self.projects = fetchedProjects
                self.isLoading = false
            }
        } catch {
            print("❌ Error fetching projects: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct TeacherProfileView: View {
    @State private var selectedTab = 0
    @Binding var isLoggedIn: Bool
    @StateObject private var projectViewModel = ProjectViewModel()
    @State private var selectedProject: Project?
    @State private var selectedVideo: Video?
    @State private var isVideoPlayerPresented = false
    
    var body: some View {
        NavigationView {
            ZStack {
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
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(projectViewModel.projects) { project in
                                    ProjectThumbnail(project: project)
                                        .onTapGesture {
                                            selectedProject = project
                                        }
                                }
                            }
                            .padding(.horizontal)
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
                .refreshable {
                    await projectViewModel.fetchProjects()
                }
                
                // Loading overlay
                if projectViewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Loading content...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(Color(UIColor.systemBackground).opacity(0.8))
                        .cornerRadius(10)
                    }
                }
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: logout) {
                        Text("Logout")
                            .foregroundColor(Theme.accentColor)
                    }
                }
            }
            .sheet(isPresented: $isVideoPlayerPresented) {
                if let video = selectedVideo {
                    VideoPlayerSheet(video: video)
                } else if let project = selectedProject {
                    // Add project player sheet here
                }
            }
        }
        .task {
            await projectViewModel.fetchProjects()
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
    @State private var projectVideos: [Video]?
    @State private var showEditView = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            ZStack {
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 150, height: 150)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                
                if isLoading {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 150, height: 150)
                        .overlay(
                            VStack(spacing: 10) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Loading videos...")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        )
                }
            }
            .contextMenu {
                Button {
                    Task {
                        await loadAndPrepareVideos()
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            Text(project.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 150)
        .fullScreenCover(isPresented: $showEditView) {
            if let projectVideos = projectVideos {
                EditExistingVideoView(videoURLs: projectVideos, project: project)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            if let thumbnailUrl = project.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        thumbnailImage = image
                    }
                } catch {
                    print("❌ Error loading thumbnail: \(error)")
                }
            }
        }
    }
    
    private func loadAndPrepareVideos() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let projectId = project.id else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No project ID found"])
            }
            
            // 1. Fetch videos from Firestore
            print("📝 Fetching videos for project: \(projectId)")
            let remoteVideos = try await ProjectService.shared.fetchProjectVideos(projectId: projectId)
            print("✅ Found \(remoteVideos.count) videos")
            
            // 2. Download each video locally
            var localVideos: [Video] = []
            for var video in remoteVideos {
                if let remoteURL = video.urlValue {
                    print("⬇️ Downloading video: \(video.id)")
                    let localURL = try await downloadVideo(remoteURL: remoteURL)
                    video.url = localURL.absoluteString
                    print("✅ Downloaded to: \(localURL.absoluteString)")
                    localVideos.append(video)
                }
            }
            
            // 3. Update state and show editor
            await MainActor.run {
                self.projectVideos = localVideos
                self.isLoading = false
                self.showEditView = true
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                print("❌ Error: \(error)")
            }
        }
    }
    
    private func downloadVideo(remoteURL: URL) async throws -> URL {
        let (data, _) = try await URLSession.shared.data(from: remoteURL)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        try data.write(to: tempURL)
        return tempURL
    }
}

struct ProjectVideosView: View {
    let project: Project
    @StateObject private var videoViewModel = VideoViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if videoViewModel.projectVideos.isEmpty {
                    Text("No videos in this project")
                        .foregroundColor(.gray)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(videoViewModel.projectVideos) { video in
                                VideoThumbnail(video: video, videoViewModel: videoViewModel)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
            }
            .navigationTitle(project.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .task {
            isLoading = true
            print("🎬 Loading videos for project: \(project.id ?? "unknown")")
            if let projectId = project.id {
                await videoViewModel.fetchProjectVideos(projectId)
            }
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
    @State private var showEditView = false
    @State private var projectVideos: [Video]?
    @State private var project: Project?
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width/2 - 15, height: (UIScreen.main.bounds.width/2 - 15) * 3/4)
                    .clipped()
                    .contextMenu {
                        Button {
                            Task {
                                print("🖊️ Edit button tapped")
                                await loadProjectAndVideos()
                            }
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
            } else if isLoading {
                ProgressView()
                    .frame(width: UIScreen.main.bounds.width/2 - 15, height: (UIScreen.main.bounds.width/2 - 15) * 3/4)
                    .background(Color(uiColor: .secondarySystemBackground))
            } else {
                Rectangle()
                    .foregroundColor(Color(uiColor: .secondarySystemBackground))
                    .frame(width: UIScreen.main.bounds.width/2 - 15, height: (UIScreen.main.bounds.width/2 - 15) * 3/4)
                    .overlay(
                        Image(systemName: "play.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.primary)
                    )
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .fullScreenCover(isPresented: $showEditView) {
            if let projectVideos = projectVideos, let project = project {
                EditExistingVideoView(videoURLs: projectVideos, project: project)
            }
        }
    }
    
    private func loadProjectAndVideos() async {
        print("📝 Starting to load project and videos...")
        do {
            let projectId = video.projectId
            print("🔑 Project ID: \(projectId)")
            
            // Fetch project and its videos
            async let projectTask = ProjectService.shared.fetchProject(projectId)
            async let videosTask = VideoViewModel.shared.fetchProjectVideos(projectId)
            
            let (project, videos) = try await (projectTask, videosTask)
            
            await MainActor.run {
                self.project = project
                self.projectVideos = videos
                self.showEditView = true
                print("🎬 Showing edit view")
            }
        } catch {
            print("❌ Error loading project and videos: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
}

struct VideoPlayerSheet: View {
    let video: Video
    @Environment(\.presentationMode) var presentationMode
    @State private var player: AVPlayer?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                        isLoading = false
                    }
                    .onDisappear {
                        player.pause()
                    }
            }
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .task {
            guard let urlValue = video.urlValue else { return }
            player = AVPlayer(url: urlValue)
        }
    }
}
