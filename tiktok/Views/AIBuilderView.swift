import SwiftUI
import FirebaseFunctions
import FirebaseStorage

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
    
    private func downloadAndSaveVideo(fromURL videoURL: String) async throws -> URL {
        await updateProgress("Downloading video...")
        
        // Convert gs:// URL to https:// URL for Firebase Storage
        let gsURL = videoURL.replacingOccurrences(of: "gs://", with: "")
        let components = gsURL.components(separatedBy: "/")
        guard components.count >= 2 else {
            throw GenerationError.invalidResponse
        }
        
        let bucket = components[0]
        let path = components.dropFirst().joined(separator: "/")
        let storageRef = storage.reference(forURL: "gs://\(bucket)").child(path)
        
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        _ = try await storageRef.write(toFile: localURL)
        
        // Save video locally with metadata
        await updateProgress("Saving video locally...")
        let projectId = "ai_generated_videos"
        let metadata = VideoMetadata(
            startTime: 0.0,
            endTime: 180.0
        )
        
        let savedURL = try videoSaver.saveVideoWithMetadata(
            from: localURL,
            projectId: projectId,
            videoId: UUID().uuidString,
            metadata: metadata
        )
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: localURL)
        
        // Successfully downloaded and saved video, update to complete
        await MainActor.run {
            generationProgress.currentStep = .complete
        }
        
        return savedURL
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
