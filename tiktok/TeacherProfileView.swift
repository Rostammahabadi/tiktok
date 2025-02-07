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
    @State private var showEditView = false
    @State private var projectVideos: [Video]?
    
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
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            Text(project.title)
                .font(.caption)
                .lineLimit(1)
        }
        .contextMenu {
            Button {
                print("🖊️ Edit button tapped from context menu")
                Task {
                    await loadProjectVideos()
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .sheet(isPresented: $showEditView) {
            if let projectVideos = projectVideos {
                EditExistingVideoView(videoURLs: projectVideos, project: project)
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
            isLoading = false
        }
    }
    
    private func loadProjectVideos() async {
        print("📝 Starting to load project videos...")
        do {
            guard let projectId = project.id else {
                print("❌ No project ID found")
                return
            }
            
            let videos = try await ProjectService.shared.fetchProjectVideos(projectId: projectId)
            print("✅ Loaded \(videos.count) videos")
            
            await MainActor.run {
                self.projectVideos = videos
                self.showEditView = true
                print("🎬 Showing edit view")
            }
        } catch {
            print("❌ Error loading project videos: \(error)")
        }
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
        .sheet(isPresented: $showEditView) {
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
//            print("✅ Loaded project and \(videos.count) videos")
            
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
