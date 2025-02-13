import SwiftUI

struct BiometricLoginView: View {
    @StateObject private var authService = BiometricAuthService()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TeacherLogo()
                .frame(width: 120, height: 120)
            
            Text("Welcome to MathTok")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Sign in with Face ID")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button(action: {
                authenticate()
            }) {
                HStack {
                    Image(systemName: "faceid")
                        .font(.title)
                    Text("Sign In with Face ID")
                        .fontWeight(.semibold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .alert("Authentication Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func authenticate() {
        Task {
            if await authService.authenticateUser() {
                // Handle successful authentication
                // You can navigate to your main app view here
                print("✅ Authentication successful")
            } else {
                await MainActor.run {
                    alertMessage = "Face ID authentication failed. Please try again."
                    showingAlert = true
                }
            }
        }
    }
}
