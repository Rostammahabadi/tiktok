import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import AVKit

class VideoViewModel: ObservableObject {
    static let shared = VideoViewModel()
    @Published var videos: [Video] = []
    @Published var userVideos: [Video] = []
    @Published var projectVideos: [Video] = []
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
                .whereField("isDeleted", isEqualTo: false)
                .getDocuments()
            
            print("📊 Found \(snapshot.documents.count) documents in Firestore")
            
            var fetchedVideos: [Video] = []
            for document in snapshot.documents {
                let data = document.data()
                let video = Video(
                    id: document.documentID,
                    authorId: data["author_id"] as? String ?? "",
                    projectId: data["project_id"] as? String ?? "",
                    url: data["url"] as? String ?? "",
                    startTime: data["startTime"] as? Double,
                    endTime: data["endTime"] as? Double
                )
                fetchedVideos.append(video)
            }
            
            await MainActor.run {
                self.videos = fetchedVideos
                print("💾 Updated videos array. Current count: \(self.videos.count)")
            }
        } catch {
            print("❌ Error fetching videos: \(error)")
        }
    }
    
    func fetchUserVideos() async {
        print("🎥 Starting to fetch user videos...")
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No current user found")
            return
        }
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            print("📝 Querying Firestore collection 'videos' for user: \(currentUserId)")
            let snapshot = try await db.collection("videos")
                .whereField("author_id", isEqualTo: currentUserId)
                .getDocuments()
            
            print("📊 Found \(snapshot.documents.count) user videos")
            
            var fetchedVideos: [Video] = []
            for document in snapshot.documents {
                let data = document.data()
                let video = Video(
                    id: document.documentID,
                    authorId: data["author_id"] as? String ?? "",
                    projectId: data["project_id"] as? String ?? "",
                    url: data["url"] as? String ?? "",
                    startTime: data["startTime"] as? Double,
                    endTime: data["endTime"] as? Double
                )
                fetchedVideos.append(video)
            }
            
            await MainActor.run {
                self.userVideos = fetchedVideos
                print("💾 Updated user videos array. Current count: \(self.userVideos.count)")
            }
        } catch {
            print("❌ Error fetching user videos: \(error)")
        }
    }
    
    func fetchProjectVideos(_ projectId: String) async -> [Video] {
        print("🎥 Starting to fetch project videos...")
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            print("📝 Querying Firestore collection 'videos' for project: \(projectId)")
            let snapshot = try await db.collection("videos")
                .whereField("project_id", isEqualTo: projectId)
                .getDocuments()
            
            print("📊 Found \(snapshot.documents.count) project videos")
            
            var fetchedVideos: [Video] = []
            for document in snapshot.documents {
                let data = document.data()
                let video = Video(
                    id: document.documentID,
                    authorId: data["author_id"] as? String ?? "",
                    projectId: data["project_id"] as? String ?? "",
                    url: data["url"] as? String ?? "",
                    startTime: data["startTime"] as? Double,
                    endTime: data["endTime"] as? Double
                )
                fetchedVideos.append(video)
            }
            
            await MainActor.run {
                self.projectVideos = fetchedVideos
            }
            
            return fetchedVideos
        } catch {
            print("❌ Error fetching project videos: \(error)")
            return []
        }
    }
    
    func deleteVideo(_ video: Video) async {
        print("🗑️ Attempting to delete video: \(video.id)")
        
        do {
            try await db.collection("videos").document(video.id).updateData([
                "isDeleted": true
            ])
            
            await fetchUserVideos()
            print("✅ Video deleted successfully")
        } catch {
            print("❌ Error deleting video: \(error.localizedDescription)")
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
