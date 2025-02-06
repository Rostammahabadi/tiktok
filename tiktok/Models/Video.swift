import Foundation
import SwiftUI

struct Video: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let authorId: String
    let videoURL: String
    let thumbnailURL: String?
    let timestamp: Date
    var status: String
    var isDeleted: Bool
    
    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         authorId: String,
         videoURL: String,
         thumbnailURL: String?,
         timestamp: Date = Date(),
         status: String = "",
         isDeleted: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.authorId = authorId
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.timestamp = timestamp
        self.status = status
        self.isDeleted = isDeleted
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case authorId
        case videoURL
        case thumbnailURL
        case timestamp
        case status
        case isDeleted
    }
    
    func loadThumbnail() async -> Image? {
        print("🖼️ Starting to load thumbnail...")
        
        guard let thumbnailURL = thumbnailURL else {
            print("❌ No thumbnail URL available")
            return nil
        }
        
        print("🔗 Attempting to load thumbnail from URL: \(thumbnailURL)")
        
        do {
            guard let url = URL(string: thumbnailURL) else {
                print("❌ Invalid thumbnail URL")
                return nil
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ HTTP error: \(httpResponse.statusCode)")
                return nil
            }
            
            guard let uiImage = UIImage(data: data) else {
                print("❌ Failed to create UIImage from data")
                return nil
            }
            
            print("✅ Successfully loaded thumbnail")
            return Image(uiImage: uiImage)
        } catch {
            print("❌ Error loading thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
} 
