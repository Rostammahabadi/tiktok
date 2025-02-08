import SwiftUI
import FirebaseAuth

struct UsernameSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLoggedIn: Bool
    let authResult: AuthDataResult
    
    @State private var username: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var showConfetti: Bool = false
    @FocusState private var isUsernameFocused: Bool
    
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
                    
                    Text("Choose Your Username")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Text("This is how other teachers will know you")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Username input field
                    VStack(spacing: 20) {
                        CustomTextField(
                            placeholder: "Username",
                            text: $username,
                            contentType: .username
                        )
                        .focused($isUsernameFocused)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Continue button
                    Button(action: completeSignup) {
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
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.white)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isLoading || username.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Text("You can change your username later in settings")
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
    }
    
    private func completeSignup() {
        guard !username.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Validate username
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedUsername.count >= 3 else {
            errorMessage = "Username must be at least 3 characters"
            isLoading = false
            return
        }
        
        guard trimmedUsername.count <= 30 else {
            errorMessage = "Username must be less than 30 characters"
            isLoading = false
            return
        }
        
        // Create user in Firestore
        Task {
            do {
                try await UserService.shared.createUserAfterAuthentication(
                    authResult: authResult,
                    username: trimmedUsername
                )
                
                DispatchQueue.main.async {
                    // Show confetti on successful signup
                    withAnimation {
                        showConfetti = true
                    }
                    
                    // Delay dismissal to show confetti
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isLoading = false
                        isLoggedIn = true
                        dismiss()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = "Failed to create user profile: \(error.localizedDescription)"
                }
            }
        }
    }
}
