import Foundation
import FirebaseAuth

class LogoutService {
    static let shared = LogoutService()
    
    private init() {}
    
    func logout() async throws {
        do {
            // Sign out from Firebase Auth
            try Auth.auth().signOut()
            
            // Clear local user data
            UserDefaultsManager.shared.clearCurrentUser()
            
            print("✅ User successfully logged out and local data cleared")
        } catch {
            print("❌ Error logging out: \(error.localizedDescription)")
            throw error
        }
    }
}
