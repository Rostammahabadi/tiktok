import Foundation
import UIKit

class LocalThumbnailService {
    static let shared = LocalThumbnailService()
    private init() {}
    
    /// Load a thumbnail image for a local project
    /// - Parameter projectId: The ID of the project
    /// - Returns: UIImage if the thumbnail exists, nil otherwise
    func loadThumbnail(projectId: String) -> UIImage? {
        do {
            let docs = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let projectFolder = docs.appendingPathComponent("LocalProjects/\(projectId)", isDirectory: true)
            let thumbnailURL = projectFolder.appendingPathComponent("thumbnail.jpeg")
            
            print("🔍 Looking for thumbnail at: \(thumbnailURL.path)")
            
            guard FileManager.default.fileExists(atPath: thumbnailURL.path) else {
                print("⚠️ No thumbnail found at: \(thumbnailURL.path)")
                return nil
            }
            
            let data = try Data(contentsOf: thumbnailURL)
            guard let image = UIImage(data: data) else {
                print("❌ Failed to create image from data at: \(thumbnailURL.path)")
                return nil
            }
            
            print("✅ Successfully loaded thumbnail for project: \(projectId)")
            return image
            
        } catch {
            print("❌ Error loading thumbnail for project \(projectId): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Load thumbnails for multiple projects in parallel
    /// - Parameter projectIds: Array of project IDs to load thumbnails for
    /// - Returns: Dictionary mapping project IDs to their thumbnail images
    func loadThumbnails(projectIds: [String]) async -> [String: UIImage] {
        print("📸 Starting to load \(projectIds.count) thumbnails...")
        
        let results = await withTaskGroup(of: (String, UIImage?).self) { group in
            for projectId in projectIds {
                group.addTask {
                    let thumbnail = self.loadThumbnail(projectId: projectId)
                    return (projectId, thumbnail)
                }
            }
            
            var thumbnails: [String: UIImage] = [:]
            for await (projectId, thumbnail) in group {
                if let thumbnail = thumbnail {
                    thumbnails[projectId] = thumbnail
                }
            }
            return thumbnails
        }
        
        print("📸 Finished loading thumbnails. Found \(results.count) of \(projectIds.count) thumbnails")
        return results
    }
}
