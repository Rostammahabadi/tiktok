import Foundation

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    private let defaults = UserDefaults.standard
    
    // Keys
    private enum Keys {
        static let currentUser = "currentUser"
    }
    
    // User data structure
    struct LocalUser: Codable {
        let id: String
        var email: String
        var username: String
        var bio: String
        let createdAt: Date
        
        init(id: String, email: String, username: String, createdAt: Date = Date(), bio: String) {
            self.id = id
            self.email = email
            self.username = username
            self.createdAt = createdAt
            self.bio = bio
        }
    }
    
    private init() {}
    
    // MARK: - User Methods
    
    func saveCurrentUser(id: String, email: String, username: String, bio: String) {
        let user = LocalUser(id: id, email: email, username: username, bio: bio)
        if let encoded = try? JSONEncoder().encode(user) {
            defaults.set(encoded, forKey: Keys.currentUser)
            print("✅ User data saved to UserDefaults - ID: \(id), Username: \(username)")
        } else {
            print("❌ Failed to encode user data for UserDefaults")
        }
    }
    
    func getCurrentUser() -> LocalUser? {
        guard let userData = defaults.data(forKey: Keys.currentUser),
              let user = try? JSONDecoder().decode(LocalUser.self, from: userData) else {
            return nil
        }
        return user
    }
    
    func clearCurrentUser() {
        defaults.removeObject(forKey: Keys.currentUser)
        print("✅ User data cleared from UserDefaults")
    }
    
    // MARK: - Helper Methods
    
    func isUserLoggedIn() -> Bool {
        return getCurrentUser() != nil
    }
}
