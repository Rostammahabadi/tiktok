import Foundation
import FirebaseAuth
import FirebaseFirestore

class UserService {
    static let shared = UserService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func createUser(email: String, username: String) async throws -> User {
        print("📝 Starting user creation in Firestore for email: \(email)")
        // Create the user object
        let now = Date()
        var user = User(
            email: email,
            username: username,
            createdAt: now,
            updatedAt: now
        )
        
        do {
            // Save to Firestore
            print("📝 Attempting to save user to Firestore...")
            let userRef = try await db.collection("users").addDocument(from: user)
            user.id = userRef.documentID
            print("✅ User successfully created in Firestore with ID: \(userRef.documentID)")
            
            // Verify the user was created by reading it back
            print("📝 Verifying user creation by reading document...")
            let verifyDoc = try await userRef.getDocument(as: User.self)
            print("✅ Successfully verified user in database:")
            print("   - Document exists: \(verifyDoc.id == userRef.documentID)")
            print("   - Email matches: \(verifyDoc.email == email)")
            print("   - Username matches: \(verifyDoc.username == username)")
            
            return user
        } catch {
            print("❌ Failed to create user in Firestore: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            throw error
        }
    }
    
    func createUserAfterAuthentication(authResult: AuthDataResult, username: String) async throws {
        print("📝 Starting user creation process after authentication")
        print("📝 Auth User ID: \(authResult.user.uid)")
        
        guard let email = authResult.user.email else {
            let error = "User email not found in auth result"
            print("❌ \(error)")
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        do {
            let user = try await createUser(email: email, username: username)
            print("✅ Complete user creation process successful")
            print("✅ User details - ID: \(user.id ?? "unknown"), Email: \(user.email)")
        } catch {
            print("❌ Failed to complete user creation process")
            print("❌ Error details: \(error)")
            throw error
        }
    }
    
    func getUser(userId: String) async throws -> User? {
        let docSnapshot = try await db.collection("users").document(userId).getDocument()
        return try docSnapshot.data(as: User.self)
    }
}
