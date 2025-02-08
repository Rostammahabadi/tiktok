import Foundation
import FirebaseFirestore

struct Project: Identifiable, Codable {
    @DocumentID var id: String?
    let authorId: String
    let title: String
    let description: String?
    let thumbnailUrl: String?
    let status: ProjectStatus
    let serializedSettings: Data?
    let isDeleted: Bool
    @ServerTimestamp var createdAt: Timestamp?
    
    enum ProjectStatus: String, Codable {
        case created
        case inProgress = "in_progress"
        case published
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case title
        case description
        case thumbnailUrl = "thumbnail_url"
        case status
        case serializedSettings = "serialization"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
    }
    
    init(id: String? = nil, authorId: String, title: String, description: String? = nil, thumbnailUrl: String? = nil, status: ProjectStatus, serializedSettings: Data? = nil, isDeleted: Bool = false, createdAt: Date? = nil) {
        self.id = id
        self.authorId = authorId
        self.title = title
        self.description = description
        self.thumbnailUrl = thumbnailUrl
        self.status = status
        self.serializedSettings = serializedSettings
        self.isDeleted = isDeleted
        if let createdAt = createdAt {
            self.createdAt = Timestamp(date: createdAt)
        }
    }
}
