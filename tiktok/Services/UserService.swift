import Foundation
import FirebaseAuth
import FirebaseFirestore

class UserService {
    static let shared = UserService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func createUser(userId: String, email: String, username: String, bio: String) async throws -> User {
        print("📝 Starting user creation in Firestore for email: \(email)")
        // Create the user object
        let now = Date()
        var user = User(
            id: userId,
            email: email,
            username: username,
            bio: bio,
            createdAt: now,
            updatedAt: now
        )
        
        do {
            // Save to Firestore using the Auth UID as document ID
            print("📝 Attempting to save user to Firestore...")
            try await db.collection("users").document(userId).setData(from: user)
            print("✅ User successfully created in Firestore with ID: \(userId)")
            
            // Verify the user was created by reading it back
            print("📝 Verifying user creation by reading document...")
            let verifyDoc = try await db.collection("users").document(userId).getDocument(as: User.self)
            print("✅ Successfully verified user in database:")
            print("   - Document exists: \(verifyDoc.id == userId)")
            print("   - Email matches: \(verifyDoc.email == email)")
            print("   - Username matches: \(verifyDoc.username == username)")
            
            return user
        } catch {
            print("❌ Failed to create user in Firestore: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            throw error
        }
    }
    
    func createUserAfterAuthentication(authResult: AuthDataResult, username: String, bio: String) async throws {
        print("📝 Starting user creation process after authentication")
        print("📝 Auth User ID: \(authResult.user.uid)")
        
        guard let email = authResult.user.email else {
            let error = "User email not found in auth result"
            print("❌ \(error)")
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        do {
            let user = try await createUser(
                userId: authResult.user.uid,
                email: email,
                username: username,
                bio: bio
            )
            
            // Save to UserDefaults
            UserDefaultsManager.shared.saveCurrentUser(
                id: authResult.user.uid,
                email: email,
                username: username,
                bio: bio
            )
            
            print("✅ Complete user creation process successful")
            print("✅ User details - ID: \(user.id ?? "unknown"), Email: \(user.email)")
        } catch {
            print("❌ Failed to complete user creation process")
            print("❌ Error details: \(error)")
            throw error
        }
    }
    
    func getUser(userId: String) async throws -> User? {
        print("📝 Fetching user with ID: \(userId)")
        let docSnapshot = try await db.collection("users").document(userId).getDocument()
        
        guard docSnapshot.exists else {
            print("❌ No user document found for ID: \(userId)")
            return nil
        }
        
        do {
            let user = try docSnapshot.data(as: User.self)
            print("✅ Successfully fetched user: \(user.username)")
            return user
        } catch {
            print("❌ Error decoding user data: \(error.localizedDescription)")
            throw error
        }
    }
    
    func updateProfile(userId: String, username: String, bio: String) async throws {
        print("📝 Updating profile for user: \(userId)")
        
        do {
            // First check if username is already taken by another user
            let query = db.collection("users")
                .whereField("username", isEqualTo: username)
                .whereField(FieldPath.documentID(), isNotEqualTo: userId)
            let snapshot = try await query.getDocuments()
            
            if !snapshot.documents.isEmpty {
                print("❌ Username \(username) is already taken")
                throw NSError(
                    domain: "UserService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Username is already taken"]
                )
            }
            
            // Update the user document
            let data: [String: Any] = [
                "username": username,
                "bio": bio,
                "updated_at": Date()
            ]
            
            try await db.collection("users").document(userId).updateData(data)
            print("✅ Successfully updated profile for user: \(userId)")
            
            // Update local storage
            if var currentUser = UserDefaultsManager.shared.getCurrentUser() {
                currentUser.username = username
                currentUser.bio = bio
                UserDefaultsManager.shared.saveCurrentUser(
                    id: currentUser.id,
                    email: currentUser.email,
                    username: username,
                    bio: bio
                )
                print("✅ Updated local user data")
            }
        } catch {
            print("❌ Failed to update profile: \(error.localizedDescription)")
            throw error
        }
    }
}
