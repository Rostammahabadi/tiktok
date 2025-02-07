import Foundation
import FirebaseFirestore
import FirebaseAuth

class VideoDocumentService {
    static let shared = VideoDocumentService()
    private let db = Firestore.firestore()
    private let videosCollection = "videos"
    
    private init() {}
    
    // MARK: - Create
    
    func createVideoDocument(in projectId: String, exportedFilePath: String, serialization: [String: Any], segments: [VideoSegment]? = nil) async throws -> VideoDocument {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot create video document: User not authenticated")
            throw NSError(domain: "VideoDocumentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("📝 Creating video document in project: \(projectId)")
        print("📝 File path: \(exportedFilePath)")
        
        let videoDoc = VideoDocument(
            exportedFilePath: exportedFilePath,
            projectId: projectId,
            authorId: userId,
            serialization: serialization,
            segments: segments
        )
        
        do {
            // Generate a new document ID
            let docRef = db.collection(videosCollection).document()
            
            // Create a dictionary with the video data
            var data: [String: Any] = [
                "exported_file_path": exportedFilePath,
                "project_id": projectId,
                "author_id": userId,
                "serialization": serialization
            ]
            
            if let segments = segments {
                data["segments"] = try JSONEncoder().encode(segments)
            }
            
            // Set the data with merge to allow server timestamp
            try await docRef.setData(data, merge: true)
            
            var savedVideo = videoDoc
            savedVideo.id = docRef.documentID
            print("✅ Video document created successfully")
            print("✅ Document ID: \(docRef.documentID)")
            return savedVideo
        } catch {
            print("❌ Failed to create video document: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            throw error
        }
    }
    
    // MARK: - Read
    
    func getVideoDocument(_ videoId: String) async throws -> VideoDocument {
        print("📝 Fetching video document: \(videoId)")
        
        let docRef = db.collection(videosCollection).document(videoId)
        
        do {
            let document = try await docRef.getDocument()
            guard let video = try? document.data(as: VideoDocument.self) else {
                print("❌ Video document not found or failed to decode")
                throw NSError(domain: "VideoDocumentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video document not found"])
            }
            print("✅ Successfully retrieved video document")
            return video
        } catch {
            print("❌ Failed to get video document: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getProjectVideos(projectId: String) async throws -> [VideoDocument] {
        print("📝 Fetching videos for project: \(projectId)")
        
        let snapshot = try await db.collection(videosCollection)
            .whereField("project_id", isEqualTo: projectId)
            .order(by: "saved_at", descending: true)
            .getDocuments()
        
        print("✅ Successfully retrieved project videos")
        return try snapshot.documents.compactMap { document in
            try document.data(as: VideoDocument.self)
        }
    }
    
    // MARK: - Update
    
    func updateVideoDocument(_ videoId: String, exportedFilePath: String? = nil, serialization: [String: Any]? = nil, segments: [VideoSegment]? = nil) async throws {
        print("📝 Updating video document: \(videoId)")
        
        var updateData: [String: Any] = [:]
        
        if let exportedFilePath = exportedFilePath {
            updateData["exported_file_path"] = exportedFilePath
        }
        if let serialization = serialization {
            updateData["serialization"] = serialization
        }
        if let segments = segments {
            updateData["segments"] = try JSONEncoder().encode(segments)
        }
        
        guard !updateData.isEmpty else { 
            print("❌ No updates to apply")
            return 
        }
        
        do {
            try await db.collection(videosCollection)
                .document(videoId)
                .updateData(updateData)
            print("✅ Video document updated successfully")
        } catch {
            print("❌ Failed to update video document: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Delete
    
    func deleteVideoDocument(_ videoId: String) async throws {
        print("📝 Deleting video document: \(videoId)")
        
        do {
            try await db.collection(videosCollection)
                .document(videoId)
                .delete()
            print("✅ Video document deleted successfully")
        } catch {
            print("❌ Failed to delete video document: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Listeners
    
    func addVideoDocumentListener(_ videoId: String, completion: @escaping (Result<VideoDocument, Error>) -> Void) -> ListenerRegistration {
        print("📝 Adding video document listener for video: \(videoId)")
        
        return db.collection(videosCollection)
            .document(videoId)
            .addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    print("❌ Video document listener error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let document = documentSnapshot else {
                    print("❌ Video document not found")
                    completion(.failure(NSError(domain: "VideoDocumentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document not found"])))
                    return
                }
                
                do {
                    let video = try document.data(as: VideoDocument.self)
                    print("✅ Video document listener received update")
                    completion(.success(video))
                } catch {
                    print("❌ Failed to decode video document: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
    }
}
