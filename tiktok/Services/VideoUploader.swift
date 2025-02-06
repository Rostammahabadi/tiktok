import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class VideoUploader: ObservableObject {
    @Published var uploadProgress: Double = 0
    @Published var isUploading = false
    @Published var error: Error?
    
    private let storage = Storage.storage().reference()
    private let db = Firestore.firestore()
    
    func uploadVideo(url: URL, title: String = "", description: String = "") async throws -> String {
        // Wait for auth
        for _ in 0..<10 {
            if Auth.auth().currentUser != nil { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        
        guard Auth.auth().currentUser != nil else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User must be authenticated to upload videos"])
        }
        
        // Update isUploading on main thread
        await MainActor.run {
            isUploading = true
        }
        
        defer {
            // Update isUploading on main thread when function exits
            Task { @MainActor in
                isUploading = false
            }
        }
        
        do {
            // Create video reference in Firebase Storage
            let videoName = "\(UUID().uuidString).mp4"
            let videoRef = storage.child("videos/\(videoName)")
            
            // Upload video with progress monitoring
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            
            return try await withCheckedThrowingContinuation { continuation in
                let uploadTask = videoRef.putFile(from: url, metadata: metadata)
                
                uploadTask.observe(.progress) { [weak self] snapshot in
                    DispatchQueue.main.async {
                        self?.uploadProgress = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
                    }
                }
                
                uploadTask.observe(.success) { [weak self] _ in
                    // Get download URL
                    videoRef.downloadURL { url, error in
                        if let error = error {
                            DispatchQueue.main.async {
                                self?.error = error
                            }
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        guard let downloadURL = url else {
                            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])
                            DispatchQueue.main.async {
                                self?.error = error
                            }
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        // Save video metadata to Firestore
                        self?.saveVideoMetadata(
                            videoURL: downloadURL.absoluteString,
                            title: title,
                            description: description
                        ) { error in
                            if let error = error {
                                DispatchQueue.main.async {
                                    self?.error = error
                                }
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: downloadURL.absoluteString)
                            }
                        }
                    }
                }
                
                uploadTask.observe(.failure) { [weak self] snapshot in
                    if let error = snapshot.error {
                        DispatchQueue.main.async {
                            self?.error = error
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    private func saveVideoMetadata(
        videoURL: String,
        title: String,
        description: String,
        completion: @escaping (Error?) -> Void
    ) {
        let videoData: [String: Any] = [
            "videoURL": videoURL,
            "title": title,
            "description": description,
            "timestamp": FieldValue.serverTimestamp(),
            "likes": 0,
            "views": 0
        ]
        
        db.collection("videos").addDocument(data: videoData) { error in
            completion(error)
        }
    }
} 