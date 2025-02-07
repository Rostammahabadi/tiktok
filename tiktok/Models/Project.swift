import Foundation
import FirebaseFirestore

struct Project: Identifiable, Codable {
    @DocumentID var id: String?
    let authorId: String
    let title: String
    let description: String?
    let status: ProjectStatus
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
        case status
        case createdAt = "created_at"
    }
    
    init(authorId: String, title: String, description: String?, status: ProjectStatus) {
        self.authorId = authorId
        self.title = title
        self.description = description
        self.status = status
    }
}
