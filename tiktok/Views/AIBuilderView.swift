import SwiftUI

struct AIBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AIBuilderViewModel()
    @FocusState private var focusedField: Field?
    
    // Form input states
    @State private var subject = ""
    @State private var topic = ""
    @State private var targetAgeGroup = AgeGroup.middleSchool
    @State private var videoDuration = Duration.short
    @State private var teachingStyle = TeachingStyle.engaging
    @State private var visualStyle = VisualStyle.modern
    @State private var includeQuiz = false
    @State private var shouldIncludeExamples = true
    @State private var pacePreference = PacePreference.moderate
    @State private var showAdvancedOptions = false
    @State private var keyboardHeight: CGFloat = 0
    
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
                                
                                CustomTextField(
                                    placeholder: "Topic (e.g., Fractions)",
                                    text: $topic,
                                    isSecure: false,
                                    style: .darkTransparent
                                )
                                .focused($focusedField, equals: .topic)
                                
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
                                
                                Menu {
                                    Picker("Teaching Style", selection: $teachingStyle) {
                                        ForEach(TeachingStyle.allCases) { style in
                                            Text(style.description).tag(style)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Teaching Style")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(teachingStyle.description)
                                            .foregroundColor(.white.opacity(0.7))
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(10)
                                }
                                
                                Menu {
                                    Picker("Visual Style", selection: $visualStyle) {
                                        ForEach(VisualStyle.allCases) { style in
                                            Text(style.description).tag(style)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Visual Style")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(visualStyle.description)
                                            .foregroundColor(.white.opacity(0.7))
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(10)
                                }
                                
                                Menu {
                                    Picker("Pace", selection: $pacePreference) {
                                        ForEach(PacePreference.allCases) { pace in
                                            Text(pace.description).tag(pace)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Pace")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(pacePreference.description)
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
                                
                                Toggle("Include Real-world Examples", isOn: $shouldIncludeExamples)
                                    .tint(.white)
                            }
                            
                            // Advanced Options (Collapsible)
                            DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                                VStack(spacing: 16) {
                                    // Language and Accessibility
                                    Menu {
                                        Picker("Language", selection: $viewModel.language) {
                                            Text("English (US)").tag("en-US")
                                            Text("English (UK)").tag("en-GB")
                                            Text("Spanish").tag("es")
                                            // Add more languages as needed
                                        }
                                    } label: {
                                        HStack {
                                            Text("Language")
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text(viewModel.languageDescription)
                                                .foregroundColor(.white.opacity(0.7))
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        .padding()
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(10)
                                    }

                                    // Captions and Subtitles
                                    Toggle("Auto-generate Captions", isOn: $viewModel.generateCaptions)
                                        .tint(.white)
                                    
                                    if viewModel.generateCaptions {
                                        Menu {
                                            Picker("Caption Style", selection: $viewModel.captionStyle) {
                                                Text("Standard").tag("standard")
                                                Text("Large").tag("large")
                                                Text("Dynamic").tag("dynamic")
                                            }
                                        } label: {
                                            HStack {
                                                Text("Caption Style")
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Text(viewModel.captionStyleDescription)
                                                    .foregroundColor(.white.opacity(0.7))
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                            .padding()
                                            .background(Color.black.opacity(0.2))
                                            .cornerRadius(10)
                                        }
                                    }

                                    // Background Music
                                    Toggle("Add Background Music", isOn: $viewModel.addBackgroundMusic)
                                        .tint(.white)
                                    
                                    if viewModel.addBackgroundMusic {
                                        Menu {
                                            Picker("Music Genre", selection: $viewModel.musicGenre) {
                                                Text("Educational").tag("educational")
                                                Text("Upbeat").tag("upbeat")
                                                Text("Calm").tag("calm")
                                                Text("None").tag("none")
                                            }
                                        } label: {
                                            HStack {
                                                Text("Music Genre")
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Text(viewModel.musicGenreDescription)
                                                    .foregroundColor(.white.opacity(0.7))
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                            .padding()
                                            .background(Color.black.opacity(0.2))
                                            .cornerRadius(10)
                                        }
                                        
                                        Slider(value: $viewModel.musicVolume, in: 0...100, step: 5)
                                            .tint(.white)
                                        HStack {
                                            Text("Music Volume: \(Int(viewModel.musicVolume))%")
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                    }

                                    // Visual Enhancements
                                    Toggle("Auto-enhance Video", isOn: $viewModel.autoEnhanceVideo)
                                        .tint(.white)
                                    
                                    // Learning Objectives
                                    Toggle("Include Learning Objectives", isOn: $viewModel.includeLearningObjectives)
                                        .tint(.white)
                                    
                                    if viewModel.includeLearningObjectives {
                                        CustomTextField(
                                            placeholder: "Learning Objectives (comma-separated)",
                                            text: $viewModel.learningObjectives,
                                            isSecure: false,
                                            style: .darkTransparent
                                        )
                                        .focused($focusedField, equals: .objectives)
                                    }
                                }
                                .padding(.top, 8)
                            }
                            .accentColor(.white)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // Generate Button
                        Button(action: {
                            Task {
                                await viewModel.generateVideo(
                                    subject: subject,
                                    topic: topic,
                                    ageGroup: targetAgeGroup,
                                    duration: videoDuration,
                                    teachingStyle: teachingStyle,
                                    visualStyle: visualStyle,
                                    includeQuiz: includeQuiz,
                                    includeExamples: shouldIncludeExamples,
                                    pace: pacePreference
                                )
                            }
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Generate Video")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                subject.isEmpty || topic.isEmpty ?
                                Color.gray :
                                Color.blue
                            )
                            .cornerRadius(15)
                            .padding(.horizontal)
                        }
                        .disabled(subject.isEmpty || topic.isEmpty)
                        
                        Spacer()
                    }
                    .padding(.bottom, keyboardHeight)
                }
                .scrollDismissesKeyboard(.interactively)
                
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
        case objectives
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
class AIBuilderViewModel: ObservableObject {
    @Published var isGenerating = false
    @Published var error: Error?
    
    @Published var language: String = "en-US"
    @Published var languageDescription: String = "English (US)"
    
    @Published var generateCaptions: Bool = false
    @Published var captionStyle: String = "standard"
    @Published var captionStyleDescription: String = "Standard"
    
    @Published var addBackgroundMusic: Bool = false
    @Published var musicGenre: String = "none"
    @Published var musicGenreDescription: String = "None"
    @Published var musicVolume: Double = 50
    
    @Published var autoEnhanceVideo: Bool = false
    
    @Published var includeLearningObjectives: Bool = false
    @Published var learningObjectives: String = ""
    
    func generateVideo(
        subject: String,
        topic: String,
        ageGroup: AgeGroup,
        duration: Duration,
        teachingStyle: TeachingStyle,
        visualStyle: VisualStyle,
        includeQuiz: Bool,
        includeExamples: Bool,
        pace: PacePreference
    ) async {
        // TODO: Implement video generation logic
        print("Generating video with parameters:")
        print("Subject: \(subject)")
        print("Topic: \(topic)")
        print("Age Group: \(ageGroup)")
        print("Duration: \(duration)")
        print("Teaching Style: \(teachingStyle)")
        print("Visual Style: \(visualStyle)")
        print("Include Quiz: \(includeQuiz)")
        print("Include Examples: \(includeExamples)")
        print("Pace: \(pace)")
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

enum TeachingStyle: String, CaseIterable, Identifiable {
    case engaging = "engaging"
    case formal = "formal"
    case conversational = "conversational"
    case storytelling = "storytelling"
    case interactive = "interactive"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .engaging: return "Engaging & Dynamic"
        case .formal: return "Formal & Professional"
        case .conversational: return "Conversational"
        case .storytelling: return "Story-based"
        case .interactive: return "Interactive"
        }
    }
}

enum VisualStyle: String, CaseIterable, Identifiable {
    case modern = "modern"
    case minimalist = "minimalist"
    case playful = "playful"
    case traditional = "traditional"
    case infographic = "infographic"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .modern: return "Modern & Clean"
        case .minimalist: return "Minimalist"
        case .playful: return "Playful & Animated"
        case .traditional: return "Traditional"
        case .infographic: return "Infographic Style"
        }
    }
}

enum PacePreference: String, CaseIterable, Identifiable {
    case slow = "slow"
    case moderate = "moderate"
    case fast = "fast"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .slow: return "Slow & Detailed"
        case .moderate: return "Moderate"
        case .fast: return "Fast-paced"
        }
    }
}

// MARK: - Preview Provider
struct AIBuilderView_Previews: PreviewProvider {
    static var previews: some View {
        AIBuilderView()
    }
}
