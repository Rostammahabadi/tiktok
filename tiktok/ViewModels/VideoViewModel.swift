import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import AVKit

class VideoViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var userVideos: [Video] = []
    @Published var isLoading = false
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    func fetchVideos() async {
        print("🎥 Starting to fetch videos...")
        print("📂 Storage bucket: \(storage.reference().bucket)")
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            print("📝 Querying Firestore collection 'videos'...")
            // Remove the type filter to get all videos
            let snapshot = try await db.collection("videos")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            print("📊 Found \(snapshot.documents.count) documents in Firestore")
            
            let fetchedVideos = try await withThrowingTaskGroup(of: Video?.self) { group in
                for document in snapshot.documents {
                    group.addTask {
                        print("\n🔍 Processing document ID: \(document.documentID)")
                        let data = document.data()
                        print("📄 Document data: \(data)")
                        
                        // Check video status
                        let status = data["status"] as? String ?? "unknown"
                        print("📊 Video status: \(status)")
                        
                        // Get the appropriate video URL based on status
                        var videoURL: URL?
                        if status == "completed", let hlsPath = data["hlsPath"] as? String {
                            // For completed videos, use HLS path
                            print("🎯 Using HLS path: \(hlsPath)")
                            do {
                                videoURL = try await self.storage.reference().child(hlsPath).downloadURL()
                            } catch {
                                print("❌ Error getting HLS URL: \(error)")
                            }
                        }
                        
                        // Fallback to original URL if HLS is not available
                        if videoURL == nil, let originalUrlString = data["originalUrl"] as? String,
                           let originalURL = URL(string: originalUrlString) {
                            print("🎯 Using original URL: \(originalUrlString)")
                            videoURL = originalURL
                        }
                        
                        guard let finalURL = videoURL else {
                            print("❌ No valid video URL found")
                            return nil
                        }
                        
                        print("✅ Final video URL: \(finalURL)")
                        
                        let timestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        
                        return Video(
                            id: document.documentID,
                            title: data["title"] as? String ?? "Video \(document.documentID.prefix(6))",
                            description: data["description"] as? String ?? "Created on \(timestamp)",
                            authorId: data["authorId"] as? String ?? "unknown",
                            videoURL: finalURL.absoluteString,
                            thumbnailURL: data["thumbnailUrl"] as? String,
                            likes: data["likes"] as? Int ?? 0,
                            views: data["views"] as? Int ?? 0,
                            timestamp: timestamp,
                            status: status
                        )
                    }
                }
                
                var videos: [Video] = []
                for try await video in group {
                    if let video = video {
                        videos.append(video)
                    }
                }
                return videos
            }
            
            print("\n📱 Total videos processed: \(fetchedVideos.count)")
            
            await MainActor.run {
                self.videos = fetchedVideos
                print("💾 Updated videos array. Current count: \(self.videos.count)")
            }
        } catch {
            print("❌ Error fetching videos: \(error)")
            print("❌ Error description: \(error.localizedDescription)")
            if let nsError = error as? NSError {
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                print("❌ Error user info: \(nsError.userInfo)")
            }
        }
    }
    
    // Helper function to list all videos in storage (for debugging)
    func listAllVideosInStorage() async {
        do {
            let storageReference = storage.reference().child("videos")
            let result = try await storageReference.listAll()
            
            print("Available videos in storage:")
            for item in result.items {
                let url = try await item.downloadURL()
                print("Video URL: \(url)")
            }
        } catch {
            print("Error listing videos: \(error)")
        }
    }
    
    func fetchUserVideos() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("🎥 Fetching videos for user: \(userId)")
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            let snapshot = try await db.collection("videos")
                .whereField("authorId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            let userVideos = try await withThrowingTaskGroup(of: Video?.self) { group in
                for document in snapshot.documents {
                    group.addTask {
                        let data = document.data()
                        
                        // Get video URLs
                        let videoURL = data["originalUrl"] as? String ?? ""
                        let thumbnailURL = data["thumbnailUrl"] as? String
                        let status = data["status"] as? String ?? "pending"
                        let timestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        
                        return Video(
                            id: document.documentID,
                            title: data["title"] as? String ?? "Untitled",
                            description: data["description"] as? String ?? "",
                            authorId: data["authorId"] as? String ?? userId,
                            videoURL: videoURL,
                            thumbnailURL: thumbnailURL,
                            likes: data["likes"] as? Int ?? 0,
                            views: data["views"] as? Int ?? 0,
                            timestamp: timestamp,
                            status: status
                        )
                    }
                }
                
                var videos: [Video] = []
                for try await video in group {
                    if let video = video {
                        videos.append(video)
                    }
                }
                return videos
            }
            
            await MainActor.run {
                self.userVideos = userVideos
            }
            
        } catch {
            print("❌ Error fetching user videos: \(error)")
        }
    }
}
