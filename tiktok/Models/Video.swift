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
