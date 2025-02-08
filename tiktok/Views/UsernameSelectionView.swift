import SwiftUI
import FirebaseAuth

struct ProfileSetupView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLoggedIn: Bool
    let authResult: AuthDataResult
    
    @State private var username = ""
    @State private var bio = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isBioFocused: Bool
    
    @State private var showConfetti: Bool = false
    
    private let gradientColors: [Color] = [
        Theme.primaryColor,
        Theme.accentColor,
        Color(red: 0.98, green: 0.4, blue: 0.4)
    ]
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(gradient: Gradient(colors: gradientColors),
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 10)
                        .offset(x: 150, y: -200)
                )
            
            ScrollView {
                VStack(spacing: 25) {
                    // Welcome animation
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.top, 40)
                    
                    Text("Choose Your Profile")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Text("This is how other teachers will know you")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Username Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose a username")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        CustomTextField(
                            placeholder: "Username",
                            text: $username,
                            isSecure: false
                        )
                        .focused($isUsernameFocused)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 20)
                    
                    // Bio Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tell us about yourself")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ZStack(alignment: .topLeading) {
                            if bio.isEmpty {
                                Text("Share a bit about yourself...")
                                    .foregroundColor(Color(.systemGray3))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $bio)
                                .frame(height: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .focused($isBioFocused)
                                .padding(1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isBioFocused ? Theme.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                    
                    // Continue Button
                    Button(action: createProfile) {
                        ZStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryColor))
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.title3)
                                    Text("Continue")
                                        .font(.headline)
                                }
                            }
                        }
                        .foregroundColor(Theme.primaryColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isLoading || username.isEmpty || bio.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Text("You can change your profile later in settings")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 10)
                    
                    Spacer(minLength: 30)
                }
            }
            
            // Confetti overlay
            ConfettiView(isActive: $showConfetti, duration: 3)
                .allowsHitTesting(false)
        }
        .onAppear {
            isUsernameFocused = true
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred. Please try again.")
        }
    }
    
    private func createProfile() {
        guard !isLoading else { return }
        
        // Validate username
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedUsername.count >= 3 else {
            errorMessage = "Username must be at least 3 characters"
            showError = true
            return
        }
        
        guard trimmedUsername.count <= 30 else {
            errorMessage = "Username must be less than 30 characters"
            showError = true
            return
        }
        
        // Validate bio
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBio.isEmpty else {
            errorMessage = "Please add a short bio about yourself"
            showError = true
            return
        }
        
        guard trimmedBio.count <= 150 else {
            errorMessage = "Bio must be less than 150 characters"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await UserService.shared.createUserAfterAuthentication(
                    authResult: authResult,
                    username: trimmedUsername,
                    bio: trimmedBio
                )
                
                // Save to UserDefaults
                UserDefaultsManager.shared.saveCurrentUser(
                    id: authResult.user.uid,
                    email: authResult.user.email ?? "",
                    username: trimmedUsername,
                    bio: trimmedBio
                )
                
                await MainActor.run {
                    isLoading = false
                    isLoggedIn = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
