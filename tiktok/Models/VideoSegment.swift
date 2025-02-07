import Foundation
import FirebaseFirestore

struct VideoSegment: Codable {
    let url: String
    var startTime: Double?
    var endTime: Double?
    
    enum CodingKeys: String, CodingKey {
        case url
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
