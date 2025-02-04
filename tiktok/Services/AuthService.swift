import Foundation
import FirebaseAuth

class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    static let shared = AuthService()
    
    init() {
        // Auto sign-in for development
        #if DEBUG
        signInForDevelopment()
        #endif
    }
    
    private func signInForDevelopment() {
        // Replace with your test credentials
        let email = "test@example.com"
        let password = "password123"
        
        Task {
            do {
                try await Auth.auth().signIn(withEmail: email, password: password)
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                }
            } catch {
                print("Development sign-in failed: \(error.localizedDescription)")
                // If sign in fails, try to create the test account
                try? await Auth.auth().createUser(withEmail: email, password: password)
                try? await Auth.auth().signIn(withEmail: email, password: password)
            }
        }
    }
} 