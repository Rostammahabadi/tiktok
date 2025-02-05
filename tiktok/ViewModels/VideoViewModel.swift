import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import AVKit

class VideoViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    func fetchVideos() async {
        print("🎥 Starting to fetch videos...")
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            print("📝 Querying Firestore collection 'videos'...")
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
                        
                        // Get the video path (HLS preferred)
                        guard let videoPath = (data["hlsPath"] as? String) ?? (data["originalPath"] as? String) else {
                            print("❌ No video path found in document")
                            return nil
                        }
                        
                        print("🎯 Found video path: \(videoPath)")
                        
                        // Convert path to URL
                        do {
                            let videoURL = try await self.storage.reference().child(videoPath).downloadURL()
                            print("✅ Got download URL: \(videoURL)")
                            
                            let timestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                            
                            return Video(
                                id: document.documentID,
                                title: "Video \(document.documentID.prefix(6))",
                                description: "Created on \(timestamp)",
                                author: "User",
                                videoURL: videoURL.absoluteString,
                                likes: 0,
                                views: 0,
                                timestamp: timestamp
                            )
                        } catch {
                            print("❌ Error getting download URL: \(error)")
                            return nil
                        }
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
}
