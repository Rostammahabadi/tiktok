import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    let email: String
    let username: String
    var profileImageUrl: String?
    var bio: String?
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
}
