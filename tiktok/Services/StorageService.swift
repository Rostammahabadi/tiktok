import Foundation
import FirebaseStorage
import FirebaseAuth

class StorageService {
    static let shared = StorageService()
    private let storage = Storage.storage()
    
    private init() {}
    
    func uploadVideo(from url: URL, projectId: String) async throws -> URL {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Read the video data
        let videoData: Data
        do {
            videoData = try Data(contentsOf: url)
        } catch {
            print("❌ Failed to read video data: \(error.localizedDescription)")
            throw error
        }
        
        // Create reference to the video in storage
        let filename = url.lastPathComponent
        let videoRef = storage.reference()
            .child("users")
            .child(userId)
            .child("projects")
            .child(projectId)
            .child("videos")
            .child(filename)
        
        print("📤 Uploading video: \(filename)")
        print("📤 From URL: \(url.absoluteString)")
        
        do {
            let metadata = StorageMetadata()
            metadata.contentType = "video/quicktime"
            
            _ = try await videoRef.putDataAsync(videoData, metadata: metadata)
            let downloadURL = try await videoRef.downloadURL()
            
            print("✅ Video uploaded successfully")
            print("📎 Download URL: \(downloadURL)")
            
            return downloadURL
        } catch {
            print("❌ Failed to upload video: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteVideo(at url: URL) async throws {
        let reference = storage.reference(forURL: url.absoluteString)
        try await reference.delete()
    }
}
