import Foundation
import FirebaseFirestore

public struct VideoSegment: Codable {
    public let url: String
    public var startTime: Double?
    public var endTime: Double?
    
    enum CodingKeys: String, CodingKey {
        case url
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
