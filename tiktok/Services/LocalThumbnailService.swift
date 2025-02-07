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
            
            guard FileManager.default.fileExists(atPath: thumbnailURL.path) else {
                return nil
            }
            
            let data = try Data(contentsOf: thumbnailURL)
            return UIImage(data: data)
        } catch {
            print("❌ Error loading thumbnail for project \(projectId): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Load thumbnails for multiple projects in parallel
    /// - Parameter projectIds: Array of project IDs
    /// - Returns: Dictionary mapping project IDs to their thumbnail images
    func loadThumbnails(projectIds: [String]) async -> [String: UIImage] {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for projectId in projectIds {
                group.addTask {
                    let thumbnail = self.loadThumbnail(projectId: projectId)
                    return (projectId, thumbnail)
                }
            }
            
            var results: [String: UIImage] = [:]
            for await (projectId, thumbnail) in group {
                if let thumbnail = thumbnail {
                    results[projectId] = thumbnail
                }
            }
            return results
        }
    }
}
