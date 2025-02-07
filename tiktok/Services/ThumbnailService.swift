import Foundation
import AVFoundation
import UIKit
import FirebaseAuth
import FirebaseStorage

class ThumbnailService {
    static let shared = ThumbnailService()
    private let storage = Storage.storage()
    
    private init() {}
    
    /// Generate a thumbnail from the first frame of a video
    /// - Parameter videoURL: URL of the video
    /// - Returns: Generated UIImage
    func generateThumbnail(from videoURL: URL) throws -> UIImage {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Get the first frame (time zero)
        let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
    
    /// Upload a thumbnail image to Firebase Storage
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - projectId: ID of the project this thumbnail belongs to
    /// - Returns: Download URL of the uploaded thumbnail
    func uploadThumbnail(_ image: UIImage, projectId: String) async throws -> URL {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ThumbnailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Convert image to data
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ThumbnailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to data"])
        }
        
        // Create reference to the thumbnail in storage
        let filename = "\(UUID().uuidString).jpg"
        let thumbnailRef = storage.reference()
            .child("users")
            .child(userId)
            .child("projects")
            .child(projectId)
            .child("thumbnail")
            .child(filename)
        
        print("📤 Uploading thumbnail: \(filename)")
        
        do {
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await thumbnailRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await thumbnailRef.downloadURL()
            
            print("✅ Thumbnail uploaded successfully")
            print("📎 Thumbnail URL: \(downloadURL)")
            
            return downloadURL
        } catch {
            print("❌ Failed to upload thumbnail: \(error.localizedDescription)")
            throw error
        }
    }
}
