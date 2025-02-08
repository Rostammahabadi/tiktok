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
            
            // 1. Fetch Firestore projects
            let fetchedProjects = try await ProjectService.shared.fetchUserProjects()
            
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
                    } else {
                        // About section
                        aboutSection
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                // Show loading indicator and refresh projects
                await projectViewModel.fetchProjects()
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout", action: logout)
                        .foregroundColor(Theme.accentColor)
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
            
            Text("Jane Smith")
                .font(Theme.titleFont)
                .foregroundColor(Theme.accentColor)
            
            Text("Math Teacher | 10 years experience")
                .font(Theme.bodyFont)
                .foregroundColor(Theme.textColor.opacity(0.8))
        }
        .padding()
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About Me")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.textColor)
            
            Text("I'm passionate about making math accessible and fun...")
                .font(Theme.bodyFont)
                .foregroundColor(Theme.textColor.opacity(0.8))
        }
        .padding(.horizontal)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5)
                Text("Loading content...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(UIColor.systemBackground).opacity(0.8))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Actions
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
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
            
            Text(project.title ?? "Untitled")
                .font(.caption)
                .foregroundColor(Theme.textColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
        }
        .frame(width: 170, height: 190)
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
        }
        .padding(.vertical, 8)
        
        // Show full editor if needed
        .fullScreenCover(isPresented: $showEditView) {
            if let projectVideos = projectVideos {
                EditExistingVideoView(videoURLs: projectVideos, project: project)
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
            print("✅ Found \(localVideos.count) videos")
            
            // 2) OPTIONAL: If those localVideos are *actually remote URLs*, you can
            //    download them. Otherwise if they are already local paths, skip.
            var finalLocalVideos: [Video] = []
            for var video in localVideos {
                if let remoteURL = video.urlValue {
                    print("⬇️ Downloading video: \(video.id)")
                    let localURL = try await downloadVideo(remoteURL: remoteURL)
                    video.url = localURL.absoluteString
                    finalLocalVideos.append(video)
                } else {
                    finalLocalVideos.append(video)
                }
            }
            
            // 3) Show the editor
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
}
