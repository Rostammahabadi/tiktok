import SwiftUI
import FirebaseFunctions
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

struct AIBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AIBuilderViewModel()
    @FocusState private var focusedField: Field?
    
    // Form input states
    @State private var subject = ""
    @State private var topic = ""
    @State private var targetAgeGroup = AgeGroup.middleSchool
    @State private var videoDuration = Duration.short
    @State private var includeQuiz = false
    @State private var showAdvancedOptions = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showProgressView = false
    
    // Matching gradient colors from app theme
    let gradientColors: [Color] = [
        Color(red: 0.98, green: 0.4, blue: 0.4),   // Playful red
        Color(red: 0.98, green: 0.8, blue: 0.3),   // Warm yellow
        Color(red: 0.4, green: 0.8, blue: 0.98)    // Sky blue
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(gradient: Gradient(colors: gradientColors),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                .ignoresSafeArea()
                
                // Main content
                ScrollView {
                    VStack(spacing: 25) {
                        // Header image/icon
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        Text("Create with AI")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Main form content
                        VStack(spacing: 20) {
                            // Basic Information Section
                            formSection("Basic Information") {
                                CustomTextField(
                                    placeholder: "Subject (e.g., Mathematics)",
                                    text: $subject,
                                    isSecure: false,
                                    style: .darkTransparent
                                )
                                .focused($focusedField, equals: .subject)
                                .textInputAutocapitalization(.words)
                                .onChange(of: subject) { newValue in
                                    subject = newValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
                                }
                                
                                CustomTextField(
                                    placeholder: "Topic (e.g., Fractions)",
                                    text: $topic,
                                    isSecure: false,
                                    style: .darkTransparent
                                )
                                .focused($focusedField, equals: .topic)
                                .textInputAutocapitalization(.words)
                                
                                Menu {
                                    Picker("Target Age Group", selection: $targetAgeGroup) {
                                        ForEach(AgeGroup.allCases) { group in
                                            Text(group.description).tag(group)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Target Age Group")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(targetAgeGroup.description)
                                            .foregroundColor(.white.opacity(0.7))
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(10)
                                }
                            }
                            
                            // Video Style Section
                            formSection("Video Style") {
                                Menu {
                                    Picker("Duration", selection: $videoDuration) {
                                        ForEach(Duration.allCases) { duration in
                                            Text(duration.description).tag(duration)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Duration")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(videoDuration.description)
                                            .foregroundColor(.white.opacity(0.7))
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(10)
                                }
                            }
                            
                            // Additional Options Section
                            formSection("Additional Options") {
                                Toggle("Include Interactive Quiz", isOn: $includeQuiz)
                                    .tint(.white)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // Generate Button
                        Button {
                            Task {
                                showProgressView = true
                                do {
                                    try await viewModel.generateVideo(
                                        subject: subject,
                                        topic: topic,
                                        ageGroup: targetAgeGroup,
                                        duration: videoDuration,
                                        includeQuiz: includeQuiz
                                    )
                                } catch {
                                    print("Error generating video: \(error)")
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Generate")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)
                            )
                            .foregroundColor(.blue)
                        }
                        .disabled(viewModel.isGenerating || subject.isEmpty || topic.isEmpty)
                        
                        // Error Display
                        if let error = viewModel.error {
                            Text(error.localizedDescription)
                                .foregroundColor(.red)
                                .font(.callout)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        // Saved Video Display
                        if let savedVideoURL = viewModel.savedVideoURL {
                            Text("Video saved to: \(savedVideoURL.path)")
                                .foregroundColor(.green)
                                .font(.callout)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, keyboardHeight)
                }
                .scrollDismissesKeyboard(.interactively)
                .sheet(isPresented: $showProgressView) {
                    GenerationProgressView(
                        progress: $viewModel.generationProgress,
                        viewModel: viewModel,
                        regenerateScript: {
                            Task {
                                do {
                                    try await viewModel.regenerateScript(
                                        subject: subject,
                                        topic: topic,
                                        ageGroup: targetAgeGroup,
                                        duration: videoDuration,
                                        includeQuiz: includeQuiz
                                    )
                                } catch {
                                    print("Error regenerating script: \(error)")
                                }
                            }
                        }
                    )
                }
                
                // Keyboard dismiss button
                if keyboardHeight > 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                focusedField = nil
                            }) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                                    .shadow(radius: 3)
                            }
                            .padding(.trailing)
                            .padding(.bottom, keyboardHeight)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                }
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                keyboardHeight = keyboardFrame.height
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
        }
    }
    
    // MARK: - Field Enum for Focus State
    private enum Field {
        case subject
        case topic
    }
    
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            content()
        }
    }
}

// MARK: - View Model
@MainActor
class AIBuilderViewModel: ObservableObject {
    @Published var isGenerating = false
    @Published var error: Error?
    @Published var generationProgress = GenerationProgress()
    @Published var savedVideoURL: URL?
    
    private let functions = Functions.functions()
    private let videoSaver = LocalVideoSaverWithMetadata()
    private let storage = Storage.storage()
    
    enum GenerationError: LocalizedError {
        case scriptGenerationFailed(String)
        case renderingFailed(String)
        case invalidResponse
        case downloadFailed(String)
        case saveFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .scriptGenerationFailed(let message):
                return "Failed to generate script: \(message)"
            case .renderingFailed(let message):
                return "Failed to render video: \(message)"
            case .invalidResponse:
                return "Received invalid response from server"
            case .downloadFailed(let message):
                return "Failed to download video: \(message)"
            case .saveFailed(let message):
                return "Failed to save video locally: \(message)"
            }
        }
    }
    
    func generateVideo(
        subject: String,
        topic: String,
        ageGroup: AgeGroup,
        duration: Duration,
        includeQuiz: Bool
    ) async throws {
        isGenerating = true
        error = nil
        savedVideoURL = nil
        generationProgress = GenerationProgress(currentStep: .scriptGeneration)
        
        do {
            // Step 1: Generate script and manim code
            let (manimCode, scriptText) = try await generateScript(
                subject: subject,
                topic: topic,
                ageGroup: ageGroup,
                duration: duration,
                includeQuiz: includeQuiz
            )
            
            // Update progress for script review
            generationProgress.scriptText = scriptText
            generationProgress.manimCode = manimCode
            generationProgress.currentStep = .scriptApproval
            
        } catch {
            handleError(error)
            throw error
        }
    }
    
    func regenerateScript(
        subject: String,
        topic: String,
        ageGroup: AgeGroup,
        duration: Duration,
        includeQuiz: Bool
    ) async throws {
        generationProgress.currentStep = .scriptGeneration
        
        do {
            let (manimCode, scriptText) = try await generateScript(
                subject: subject,
                topic: topic,
                ageGroup: ageGroup,
                duration: duration,
                includeQuiz: includeQuiz
            )
            
            generationProgress.scriptText = scriptText
            generationProgress.manimCode = manimCode
            generationProgress.currentStep = .scriptApproval
            
        } catch {
            handleError(error)
            throw error
        }
    }
    
    func continueWithVideo() async throws {
        guard !generationProgress.manimCode.isEmpty else {
            throw GenerationError.invalidResponse
        }
        
        do {
            // Step 1: Render video
            await MainActor.run {
                generationProgress.currentStep = .videoRendering
                generationProgress.message = "Rendering your educational video..."
            }
            
            let videoURL = try await renderVideo(manimCode: generationProgress.manimCode)
            let savedURL = try await downloadAndSaveVideo(fromURL: videoURL)
            
            await MainActor.run {
                savedVideoURL = savedURL
                isGenerating = false
            }
            
        } catch {
            await MainActor.run {
                generationProgress.currentStep = .scriptApproval
                generationProgress.message = "Error: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    private func updateProgress(_ message: String) async {
        await MainActor.run {
            generationProgress.message = message
        }
    }
    
    func generateScript(
        subject: String,
        topic: String,
        ageGroup: AgeGroup,
        duration: Duration,
        includeQuiz: Bool
    ) async throws -> (String, String) {
        await updateProgress("Generating educational script...")
        
        // Create script data - only trim whitespace from subject
        let scriptData = [
            "subject": subject.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: ""),
            "topic": topic.trimmingCharacters(in: .whitespacesAndNewlines),  // Allow spaces within topic
            "ageGroup": ageGroup.rawValue,
            "duration": duration.rawValue,
            "includeQuiz": includeQuiz,
            "includeExamples": false
        ] as [String: Any]
        
        print("Script data structure:")
        print(String(data: try JSONSerialization.data(withJSONObject: scriptData, options: .prettyPrinted), encoding: .utf8) ?? "")
        
        // Make direct HTTP request to Cloud Function
        guard let url = URL(string: "https://us-central1-tiktok-2c2fa.cloudfunctions.net/script_creation_gcf") else {
            throw GenerationError.scriptGenerationFailed("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: scriptData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("Raw response data: \(String(data: data, encoding: .utf8) ?? "")")
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw GenerationError.scriptGenerationFailed("HTTP error: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
            }
            
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let manimCode = jsonResponse["manim_code"] as? String,
                  let scriptText = jsonResponse["script_text"] as? String else {
                print("Failed to parse response: \(String(data: data, encoding: .utf8) ?? "")")
                throw GenerationError.scriptGenerationFailed("Invalid response format")
            }
            
            print("Successfully got manim code and script text")
            return (manimCode, scriptText)
            
        } catch {
            print("Script generation error: \(error)")
            throw GenerationError.scriptGenerationFailed(error.localizedDescription)
        }
    }
    
    private func renderVideo(manimCode: String) async throws -> String {
        await updateProgress("Rendering animation...")
        let videoId = UUID().uuidString
        
        // Match the exact curl request structure for Cloud Run
        let renderData = [
            "manim_code": manimCode,
            "outputBucket": "tiktok-2c2fa.firebasestorage.app",  // Fixed bucket name
            "outputPath": "videos/original/\(videoId).mov",
            "qualityFlag": "-qm"
        ] as [String: Any]
        
        print("Render data structure:")
        print(String(data: try JSONSerialization.data(withJSONObject: renderData, options: .prettyPrinted), encoding: .utf8) ?? "")
        
        do {
            // Create URL request to Cloud Run with longer timeout
            let url = URL(string: "https://manim-renderer-304885692447.us-central1.run.app")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: renderData)
            request.timeoutInterval = 300 // 5 minutes timeout
            
            // Configure session for background tasks
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 300
            config.waitsForConnectivity = true
            let session = URLSession(configuration: config)
            
            // Make request to Cloud Run
            let (data, response) = try await session.data(for: request)
            
            print("Raw render response: \(String(data: data, encoding: .utf8) ?? "")")
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("HTTP error: \(response)")
                throw GenerationError.renderingFailed("HTTP error: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
            }
            
            guard let renderDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let videoURL = renderDict["finalVideoUrl"] as? String else {
                print("Failed to parse render result: \(String(data: data, encoding: .utf8) ?? "")")
                throw GenerationError.renderingFailed("Invalid response format")
            }
            
            // Successfully rendered video, update to download step
            await MainActor.run {
                generationProgress.currentStep = .videoDownload
            }
            
            return videoURL
            
        } catch {
            print("Render error: \(error)")
            throw GenerationError.renderingFailed(error.localizedDescription)
        }
    }
    
    public func downloadAndSaveVideo(fromURL videoURL: String) async throws -> URL {
        print("=== DOWNLOAD PROCESS START ===")
        print("1. Initial video URL: \(videoURL)")
        
        let gsURL = videoURL.replacingOccurrences(of: "gs://", with: "")
        let components = gsURL.components(separatedBy: "/")
        guard components.count >= 2 else {
            throw GenerationError.invalidResponse
        }
        
        let bucket = components[0]
        let path = components.dropFirst().joined(separator: "/")
        let storageRef = storage.reference(forURL: "gs://\(bucket)").child(path)
        
        print("2. Firebase Storage reference created: \(storageRef.fullPath)")
        
        // Check tmp directory access
        let tmpDirectory = FileManager.default.temporaryDirectory
        print("3. Checking tmp directory: \(tmpDirectory.path)")
        
        let isWritable = FileManager.default.isWritableFile(atPath: tmpDirectory.path)
        print("4. Tmp directory writable: \(isWritable)")
        
        // Try to create a test file
        let testFile = tmpDirectory.appendingPathComponent("test.txt")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            print("5. Successfully wrote and removed test file")
        } catch {
            print("5. ERROR: Failed to write test file: \(error.localizedDescription)")
        }
        
        let originalFileName = path.components(separatedBy: "/").last ?? "\(UUID().uuidString).mov"
        let localURL = tmpDirectory.appendingPathComponent(originalFileName)
        
        print("6. Will download to: \(localURL.path)")
        
        do {
            print("7. Starting Firebase download...")
            
            // Try to get metadata first to confirm file exists in storage
            let storageMetadata = try await storageRef.getMetadata()
            print("8. File exists in storage with size: \(storageMetadata.size) bytes")
            
            // Create a download task
            return try await withCheckedThrowingContinuation { continuation in
                print("9. Creating download task...")
                let downloadTask = storageRef.write(toFile: localURL)
                
                downloadTask.observe(.success) { snapshot in
                    print("10. Download task completed successfully")
                    
                    // Verify file exists and has content
                    if FileManager.default.fileExists(atPath: localURL.path),
                       let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path),
                       let fileSize = attributes[.size] as? Int64,
                       fileSize > 0 {
                        print("11. File exists with size: \(fileSize) bytes")
                        
                        // Create project document first
                        let projectRef = Firestore.firestore().collection("projects").document()
                        let projectId = projectRef.documentID
                        print("📝 Created project with ID: \(projectId)")
                        
                        // Save video with metadata
                        do {
                            print("12. Starting video save with metadata...")
                            let videoMetadata = VideoMetadata(
                                startTime: 0.0,
                                endTime: 180.0
                            )
                            
                            let savedURL = try self.videoSaver.saveVideoWithMetadata(
                                from: localURL,
                                projectId: projectId,
                                videoId: originalFileName.replacingOccurrences(of: ".mov", with: ""),
                                metadata: videoMetadata
                            )
                            print("13. Video saved successfully to: \(savedURL.path)")

                            // Upload video and create project using the saved URL
                            Task {
                                do {
                                    guard let userId = Auth.auth().currentUser?.uid else {
                                        print("❌ No authenticated user")
                                        return
                                    }
                                    
                                    // Create video document first
                                    let videoId = originalFileName.replacingOccurrences(of: ".mov", with: "")
                                    let videoPath = "videos/original/\(videoId).mp4" // Match the path pattern from SaveVideoToRemoteURL
                                    
                                    // Generate thumbnail and save both locally and remotely
                                    print("📸 Generating thumbnail...")
                                    let thumbnailData = try? await SaveVideoToLocalURL().generateThumbnail(from: savedURL)
                                    var thumbnailURL: URL?
                                    
                                    // Create local project structure
                                    let docsURL = try FileManager.default.url(for: .documentDirectory,
                                                                          in: .userDomainMask,
                                                                          appropriateFor: nil,
                                                                          create: true)
                                    let projectFolder = docsURL.appendingPathComponent("LocalProjects/\(projectId)", isDirectory: true)
                                    try FileManager.default.createDirectory(at: projectFolder, withIntermediateDirectories: true)
                                    
                                    // Save video in videos/0
                                    let videosFolder = projectFolder.appendingPathComponent("videos", isDirectory: true)
                                    try FileManager.default.createDirectory(at: videosFolder, withIntermediateDirectories: true)
                                    let localVideoPath = videosFolder.appendingPathComponent("0") // main video is always "0"
                                    try FileManager.default.copyItem(at: savedURL, to: localVideoPath)
                                    print("✅ Saved main video locally at: \(localVideoPath.path)")
                                    
                                    if let thumbnailData = thumbnailData {
                                        // Save thumbnail locally
                                        let localThumbnailURL = projectFolder.appendingPathComponent("thumbnail.jpeg")
                                        try thumbnailData.write(to: localThumbnailURL)
                                        print("✅ Saved local thumbnail to: \(localThumbnailURL.path)")
                                        
                                        // Save thumbnail to Firebase Storage
                                        let thumbnailPath = "videos/thumbnails/\(videoId).jpg"
                                        let thumbnailRef = Storage.storage().reference().child(thumbnailPath)
                                        try await thumbnailRef.putDataAsync(thumbnailData)
                                        thumbnailURL = try await thumbnailRef.downloadURL()
                                        print("✅ Saved remote thumbnail to: \(thumbnailPath)")
                                    }
                                    
                                    // Create and save project.json
                                    let mainSegment = LocalSegment(
                                        segmentId: videoId,
                                        localFilePath: "videos/0", // relative path
                                        startTime: 0,
                                        endTime: nil,
                                        order: 0
                                    )
                                    
                                    let localProject = LocalProject(
                                        projectId: projectId,
                                        authorId: userId,
                                        createdAt: Date(),
                                        isDeleted: false,
                                        mainVideoId: videoId,
                                        mainVideoFilePath: "videos/0", // relative path
                                        mainThumbnailFilePath: "thumbnail.jpeg",
                                        segments: [mainSegment], // Include main video as a segment
                                        serialization: nil // AI video has no initial serialization
                                    )
                                    
                                    let projectJSONURL = projectFolder.appendingPathComponent("project.json")
                                    let encoder = JSONEncoder()
                                    encoder.dateEncodingStrategy = .iso8601
                                    encoder.outputFormatting = .prettyPrinted
                                    let encodedProj = try encoder.encode(localProject)
                                    
                                    if FileManager.default.fileExists(atPath: projectJSONURL.path) {
                                        try FileManager.default.removeItem(at: projectJSONURL)
                                    }
                                    try encodedProj.write(to: projectJSONURL)
                                    print("✅ Saved project.json at: \(projectJSONURL.path)")
                                    
                                    // Create Firestore doc for the video
                                    let videoDocData: [String: Any] = [
                                        "author_id": userId,
                                        "project_id": projectId,
                                        "originalPath": videoPath,
                                        "thumbnailUrl": thumbnailURL?.absoluteString ?? NSNull(),
                                        "created_at": FieldValue.serverTimestamp(),
                                        "status": "processing", // Will be updated after HLS
                                        "is_deleted": false,
                                        "type": "main",
                                        "order": 0
                                    ]
                                    
                                    try await Firestore.firestore().collection("videos").document(videoId).setData(videoDocData)
                                    print("✅ Created video document with ID: \(videoId)")
                                    
                                    // Create project document
                                    let projectData: [String: Any] = [
                                        "id": projectId,
                                        "author_id": userId,
                                        "created_at": FieldValue.serverTimestamp(),
                                        "main_video_id": videoId,
                                        "segment_ids": [videoId], // AI video is its own segment
                                        "thumbnail_url": thumbnailURL?.absoluteString ?? NSNull(),
                                        "is_deleted": false,
                                        "type": "ai_generated"
                                    ]
                                    
                                    try await projectRef.setData(projectData)
                                    print("✅ Created project document")
                                    
                                    // Upload video to Firebase Storage
                                    print("📤 Uploading video to Firebase Storage...")
                                    let videoRef = Storage.storage().reference().child(videoPath)
                                    let metadata = StorageMetadata()
                                    metadata.contentType = "video/mp4"
                                    
                                    try await videoRef.putFileAsync(from: savedURL, metadata: metadata)
                                    print("✅ Video uploaded successfully")
                                    
                                    // Now that the video is uploaded, trigger HLS conversion
                                    SaveVideoToRemoteURL().convertToHLS(filePath: videoPath, videoId: videoId)
                                    print("🎬 Triggered HLS conversion for video: \(videoId)")
                                    
                                } catch {
                                    print("❌ Failed to create database records: \(error)")
                                }
                            }
                            
                            // Clean up temp file
                            try? FileManager.default.removeItem(at: localURL)
                            
                            // Update progress
                            Task { @MainActor in
                                self.generationProgress.currentStep = .complete
                            }
                            
                            continuation.resume(returning: savedURL)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        print("11. ERROR: File does not exist or is empty after download")
                        continuation.resume(throwing: GenerationError.downloadFailed("File not found or empty after download"))
                    }
                }
                
                downloadTask.observe(.failure) { snapshot in
                    if let error = snapshot.error as? NSError {
                        print("ERROR: Download failed with error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
                
                downloadTask.observe(.progress) { snapshot in
                    if let progress = snapshot.progress {
                        let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        // Safely handle progress percentage
                        if percentComplete.isFinite {
                            print("Download progress: \(Int(percentComplete * 100))%")
                        }
                    }
                }
            }
        } catch {
            print("ERROR during process: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func handleError(_ error: Error) {
        isGenerating = false
        self.error = error
        print("Error generating video: \(error)")
    }
}

// MARK: - Enums
enum AgeGroup: String, CaseIterable, Identifiable {
    case elementary = "elementary"
    case middleSchool = "middle_school"
    case highSchool = "high_school"
    case college = "college"
    case adult = "adult"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .elementary: return "Elementary School"
        case .middleSchool: return "Middle School"
        case .highSchool: return "High School"
        case .college: return "College"
        case .adult: return "Adult Education"
        }
    }
}

enum Duration: String, CaseIterable, Identifiable {
    case short = "short"      // 30-60 seconds
    case medium = "medium"    // 1-2 minutes
    case long = "long"        // 2-3 minutes
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .short: return "Short (30-60 sec)"
        case .medium: return "Medium (1-2 min)"
        case .long: return "Long (2-3 min)"
        }
    }
}

// MARK: - Preview Provider
struct AIBuilderView_Previews: PreviewProvider {
    static var previews: some View {
        AIBuilderView()
    }
}
