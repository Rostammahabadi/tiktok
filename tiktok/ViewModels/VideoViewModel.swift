import SwiftUI
import FirebaseFirestore
import AVKit

class VideoViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    private let db = Firestore.firestore()
    
    func fetchVideos() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            let snapshot = try await db.collection("videos")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            let fetchedVideos = snapshot.documents.compactMap { document -> Video? in
                let data = document.data()
                guard let title = data["title"] as? String,
                      let description = data["description"] as? String,
                      let videoURL = data["videoURL"] as? String,
                      let likes = data["likes"] as? Int,
                      let views = data["views"] as? Int,
                      let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                    return nil
                }
                
                return Video(
                    id: document.documentID,
                    title: title,
                    description: description,
                    author: "Teacher", // You'll want to fetch this from user data
                    videoURL: videoURL,
                    likes: likes,
                    views: views,
                    timestamp: timestamp
                )
            }
            
            await MainActor.run {
                self.videos = fetchedVideos
            }
        } catch {
            print("Error fetching videos: \(error)")
        }
    }
    
    
}
