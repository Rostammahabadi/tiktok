import SwiftUI
import FirebaseAuth
import AVKit

// MARK: - ViewModel
class ProjectViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var thumbnails: [String: UIImage] = [:] // projectId -> thumbnail
    @Published var isLoading = false
    
    func fetchProjects() async {
        await MainActor.run { 
            isLoading = true
            // Clear existing thumbnails to force a fresh load
            thumbnails.removeAll()
        }
        
        do {
            let docsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            print("📂 Documents Directory: \(docsURL.path)")
            
            // 1. Try to load from local storage first
            var fetchedProjects: [Project] = []
            do {
                print("📱 Loading projects from local storage...")
                fetchedProjects = try await LocalProjectService.shared.loadAllLocalProjects()
                print("✅ Found \(fetchedProjects.count) local projects")
            } catch {
                print("⚠️ Failed to load local projects: \(error.localizedDescription)")
                print("🔄 Falling back to Firestore...")
                // Fallback to Firestore if local loading fails
                fetchedProjects = try await ProjectService.shared.fetchUserProjects()
            }
            
            // 2. Load all thumbnails in parallel
            let projectIds = fetchedProjects.compactMap { $0.id }
            print("🔄 Refreshing thumbnails for \(projectIds.count) projects...")
            let loadedThumbnails = await LocalThumbnailService.shared.loadThumbnails(projectIds: projectIds)
            
            // 3. Update UI state
            await MainActor.run {
                self.projects = fetchedProjects
                self.thumbnails = loadedThumbnails
                self.isLoading = false
            }
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            await MainActor.run { self.isLoading = false }
        }
    }
}

// MARK: - TeacherProfileView
struct TeacherProfileView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var projectViewModel = ProjectViewModel()
    @State private var selectedTab = 0
    @State private var isLoggingOut = false
    @State private var showLogoutError = false
    @State private var showEditProfile = false
    
    private var currentUser: UserDefaultsManager.LocalUser? {
        UserDefaultsManager.shared.getCurrentUser()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    profileHeader
                        .padding(.horizontal)
                    
                    // Tab view
                    Picker("", selection: $selectedTab) {
                        Text("Projects").tag(0)
                        Text("About").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if selectedTab == 0 {
                        // Projects Grid
                        if projectViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(projectViewModel.projects) { project in
                                    ProjectThumbnail(
                                        project: project,
                                        viewModel: projectViewModel
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // About section
                        aboutSection
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await projectViewModel.fetchProjects()
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showEditProfile = true }) {
                            Image(systemName: "pencil.circle")
                                .imageScale(.large)
                                .foregroundColor(Theme.accentColor)
                        }
                        
                        Button(action: handleLogout) {
                            if isLoggingOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Logout")
                                    .foregroundColor(Theme.accentColor)
                            }
                        }
                        .disabled(isLoggingOut)
                    }
                }
            }
            .alert("Logout Error", isPresented: $showLogoutError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Failed to logout. Please try again.")
            }
            .sheet(isPresented: $showEditProfile) {
                if let user = currentUser {
                    EditProfileView(currentUsername: user.username, currentBio: user.bio)
                }
            }
        }
        .task {
            await projectViewModel.fetchProjects()
        }
    }
    
    // MARK: - Subviews
    
    private var profileHeader: some View {
        VStack {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(Theme.accentColor)
            
            if let user = currentUser {
                Text(user.username)
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.accentColor)
                
                Text(user.email)
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textColor.opacity(0.8))
            } else {
                Text("Loading...")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.accentColor)
            }
        }
        .padding()
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About Me")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.textColor)
            
            if let user = currentUser {
                Text(user.bio)
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textColor.opacity(0.8))
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func handleLogout() {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        
        Task {
            do {
                try await LogoutService.shared.logout()
                await MainActor.run {
                    isLoggingOut = false
                    isLoggedIn = false
                }
            } catch {
                await MainActor.run {
                    isLoggingOut = false
                    showLogoutError = true
                }
            }
        }
    }
}

// MARK: - ProjectThumbnail
struct ProjectThumbnail: View {
    let project: Project
    @ObservedObject var viewModel: ProjectViewModel
    
    @State private var projectVideos: [Video]?
    @State private var showEditView = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Thumbnail image or placeholder
                if let image = viewModel.thumbnails[project.id ?? ""] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipped()
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.accentColor.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    // No image? Placeholder
                    placeholderView
                }
                
                // If loading
                if isLoading {
                    loadingOverlay
                }
                
                // If error
                if let error = errorMessage {
                    errorOverlay(error)
                }
            }
            .frame(width: 150, height: 150)
        }
        .frame(width: 170, height: 150)
        .contentShape(Rectangle())  // Make entire area tappable
        .contextMenu {
            Button {
                Task {
                    print("🖊️ Edit: \(project.id ?? "none")")
                    await loadAndPrepareVideos()
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button {
                Task {
                    await shareVideo()
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .padding(.vertical, 8)
        
        // Show full editor if needed
        .fullScreenCover(isPresented: $showEditView) {
            if let projectVideos = projectVideos {
                EditExistingVideoView(videoURLs: projectVideos, project: project)
            }
        }
        
        // Share sheet
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
        
        // Show error alert
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Placeholder
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Theme.accentColor.opacity(0.1))
            .frame(width: 150, height: 150)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Theme.accentColor.opacity(0.5))
                    
                    Text(project.title ?? "Untitled")
                        .font(.caption)
                        .foregroundColor(Theme.textColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            )
    }
    
    // MARK: - Overlays
    private var loadingOverlay: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.7))
            .frame(width: 150, height: 150)
            .overlay(
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .foregroundColor(.white)
                        .font(.caption2)
                }
            )
    }
    
    private func errorOverlay(_ error: String) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.red.opacity(0.7))
            .frame(width: 150, height: 150)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            )
    }
    
    // MARK: - Loading & Editing
    private func loadAndPrepareVideos() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let projectId = project.id else {
                throw NSError(domain: "", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "No project ID found"])
            }
            
            print("📝 Loading videos locally for project: \(projectId)")
            // 1) Load local videos from /Documents/LocalProjects
            let localVideos = try await LocalProjectService.shared.loadAndPrepareVideosLocally(projectId: projectId)
            print("✅ Found \(localVideos.videos.count) videos")
            
            // 2. OPTIONAL: If those localVideos are *actually remote URLs*, you can
            //    download them. Otherwise if they are already local paths, skip.
            var finalLocalVideos: [Video] = []
            for var video in localVideos.videos {
                if let remoteURL = video.urlValue {
                    print("⬇️ Downloading video: \(video.id)")
                    let localURL = try await downloadVideo(remoteURL: remoteURL)
                    video.url = localURL.absoluteString
                    finalLocalVideos.append(video)
                } else {
                    finalLocalVideos.append(video)
                }
            }
            
            // 3. Show the editor
            await MainActor.run {
                self.projectVideos = finalLocalVideos
                self.isLoading = false
                self.showEditView = true
            }
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // Example method to download a remote URL to local temp
    private func downloadVideo(remoteURL: URL) async throws -> URL {
        let (data, _) = try await URLSession.shared.data(from: remoteURL)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        try data.write(to: tempURL)
        return tempURL
    }
    
    private func shareVideo() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let projectId = project.id else {
                throw NSError(domain: "", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No project ID found"])
            }
            
            print("📝 Loading video for sharing: \(projectId)")
            
            // Get path to main video (stored as index "0" in videos folder)
            let docsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            
            let mainVideoPath = docsURL
                .appendingPathComponent("LocalProjects")
                .appendingPathComponent(projectId)
                .appendingPathComponent("videos")
                .appendingPathComponent("0") // Main video is always "0"
            
            // Verify the file exists
            guard FileManager.default.fileExists(atPath: mainVideoPath.path) else {
                throw NSError(domain: "", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
            }
            
            // Create a temporary copy with proper extension (.mov since that's what we export as)
            let tempDir = FileManager.default.temporaryDirectory
            let tempVideoPath = tempDir.appendingPathComponent("\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: mainVideoPath, to: tempVideoPath)
            
            await MainActor.run {
                self.shareURL = tempVideoPath
                self.showShareSheet = true
                self.isLoading = false
            }
        } catch {
            print("❌ Error preparing video for sharing: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to prepare video for sharing"
                self.isLoading = false
            }
        }
    }
}

// Share Sheet using UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
