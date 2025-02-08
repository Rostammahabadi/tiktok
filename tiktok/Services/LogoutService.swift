import Foundation
import FirebaseAuth

class LogoutService {
    static let shared = LogoutService()
    
    private init() {}
    
    func logout() async throws {
        // 1. Clear local storage
        let docsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let localProjectsDir = docsURL.appendingPathComponent("LocalProjects")
        
        if FileManager.default.fileExists(atPath: localProjectsDir.path) {
            try FileManager.default.removeItem(at: localProjectsDir)
            print("🗑️ Cleared local storage")
        }
        
        // 2. Sign out from Firebase
        try Auth.auth().signOut()
        print("👋 User signed out")
    }
}
