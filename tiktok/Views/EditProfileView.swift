import SwiftUI
import FirebaseAuth

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @State private var username: String
    @State private var bio: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isBioFocused: Bool
    
    init(currentUsername: String, currentBio: String?) {
        _username = State(initialValue: currentUsername)
        _bio = State(initialValue: currentBio ?? "")
    }
    
    private let gradientColors: [Color] = [
        Theme.primaryColor,
        Theme.accentColor,
        Color(red: 0.98, green: 0.4, blue: 0.4)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
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
                        // Profile Image (placeholder for future feature)
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            CustomTextField(
                                placeholder: "Username",
                                text: $username,
                                isSecure: false,
                                style: .darkTransparent
                            )
                            .focused($isUsernameFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        }
                        .padding(.horizontal)
                        
                        // Bio Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $bio)
                                    .frame(height: 100)
                                    .padding(12)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(12)
                                    .focused($isBioFocused)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(8)
                        }
                        
                        // Save Button
                        Button(action: saveProfile) {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryColor))
                                } else {
                                    Text("Save Changes")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(Theme.primaryColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your profile has been updated successfully!")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred. Please try again.")
        }
    }
    
    private func saveProfile() {
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
        guard trimmedBio.count <= 150 else {
            errorMessage = "Bio must be less than 150 characters"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else {
                    throw NSError(domain: "EditProfile", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
                }
                
                try await UserService.shared.updateProfile(
                    userId: userId,
                    username: trimmedUsername,
                    bio: trimmedBio.isEmpty ? "" : trimmedBio
                )
                
                await MainActor.run {
                    isLoading = false
                    showSuccess = true
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
