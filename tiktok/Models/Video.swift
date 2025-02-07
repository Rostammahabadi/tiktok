import Foundation
import SwiftUI

struct Video: Identifiable, Codable {
    let id: String
    let authorId: String
    let projectId: String
    let url: String
    let startTime: Double?
    let endTime: Double?
    
    init(id: String = UUID().uuidString,
         authorId: String,
         projectId: String,
         url: String,
         startTime: Double? = nil,
         endTime: Double? = nil) {
        self.id = id
        self.authorId = authorId
        self.projectId = projectId
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case projectId = "project_id"
        case url
        case startTime = "start_time"
        case endTime = "end_time"
    }
    
    var urlValue: URL? {
        URL(string: url)
    }
}
