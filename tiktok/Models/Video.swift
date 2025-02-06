import Foundation
import SwiftUI

struct Video: Identifiable {
    let id: String
    let title: String
    let description: String
    let authorId: String
    let videoURL: String
    let thumbnailURL: String?
    var likes: Int
    var views: Int
    let timestamp: Date
    var status: String
    
    func loadThumbnail() async -> Image? {
        guard let thumbnailURL = thumbnailURL,
              let url = URL(string: thumbnailURL),
              let data = try? await URLSession.shared.data(from: url).0,
              let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
} 
