import Foundation
import FirebaseFirestore

struct VideoDocument: Identifiable, Codable {
    @DocumentID var id: String?
    let exportedFilePath: String
    let projectId: String
    let authorId: String
    let serialization: [String: Any]
    var segments: [VideoSegment]?
    @ServerTimestamp var savedAt: Timestamp?
    
    enum CodingKeys: String, CodingKey {
        case id
        case exportedFilePath = "exported_file_path"
        case projectId = "project_id"
        case authorId = "author_id"
        case serialization
        case segments
        case savedAt = "saved_at"
    }
    
    // Custom encoding for serialization dictionary
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(exportedFilePath, forKey: .exportedFilePath)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(segments, forKey: .segments)
        try container.encode(savedAt, forKey: .savedAt)
        
        // Encode serialization dictionary manually since it's [String: Any]
        let serializationData = try JSONSerialization.data(withJSONObject: serialization)
        let serializationString = String(data: serializationData, encoding: .utf8)
        try container.encode(serializationString, forKey: .serialization)
    }
    
    // Custom decoding for serialization dictionary
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        exportedFilePath = try container.decode(String.self, forKey: .exportedFilePath)
        projectId = try container.decode(String.self, forKey: .projectId)
        authorId = try container.decode(String.self, forKey: .authorId)
        segments = try container.decodeIfPresent([VideoSegment].self, forKey: .segments)
        savedAt = try container.decodeIfPresent(Timestamp.self, forKey: .savedAt)
        
        // Decode serialization dictionary manually
        let serializationString = try container.decode(String.self, forKey: .serialization)
        if let data = serializationString.data(using: .utf8),
           let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            serialization = dict
        } else {
            serialization = [:]
        }
    }
    
    // Regular initializer
    init(id: String? = nil, exportedFilePath: String, projectId: String, authorId: String, serialization: [String: Any], segments: [VideoSegment]? = nil, savedAt: Timestamp? = nil) {
        self.id = id
        self.exportedFilePath = exportedFilePath
        self.projectId = projectId
        self.authorId = authorId
        self.serialization = serialization
        self.segments = segments
        self.savedAt = savedAt
    }
}
