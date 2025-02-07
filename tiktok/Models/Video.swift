import Foundation
import SwiftUI

struct Video: Identifiable, Codable {
    let id: String
    let authorId: String
    let projectId: String
    var url: String
    let storagePath: String
    let startTime: Double?
    let endTime: Double?
    let order: Int
    let isDeleted: Bool
    
    init(id: String = UUID().uuidString,
         authorId: String,
         projectId: String,
         url: String,
         storagePath: String,
         startTime: Double? = nil,
         endTime: Double? = nil,
         order: Int = 0,
         isDeleted: Bool = false) {
        self.id = id
        self.authorId = authorId
        self.projectId = projectId
        self.url = url
        self.storagePath = storagePath
        self.startTime = startTime
        self.endTime = endTime
        self.order = order
        self.isDeleted = isDeleted
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case projectId = "project_id"
        case url
        case storagePath = "storage_path"
        case startTime = "start_time"
        case endTime = "end_time"
        case order
        case isDeleted = "is_deleted"
    }
    
    var urlValue: URL? {
        URL(string: url)
    }
}
