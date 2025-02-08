import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    let email: String
    var username: String
    var profileImageUrl: String?
    var bio: String
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case profileImageUrl = "profile_image_url"
        case bio
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: String? = nil,
         email: String,
         username: String,
         bio: String,
         profileImageUrl: String? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.email = email
        self.username = username
        self.bio = bio
        self.profileImageUrl = profileImageUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
