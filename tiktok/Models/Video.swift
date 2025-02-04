import Foundation

struct Video: Identifiable {
    let id: String
    let title: String
    let description: String
    let author: String
    let videoURL: String
    var likes: Int
    var views: Int
    let timestamp: Date
} 