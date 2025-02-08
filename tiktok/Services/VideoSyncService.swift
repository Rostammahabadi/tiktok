import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class VideoSyncService {
    static let shared = VideoSyncService()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Syncs all projects and their videos from Firebase to local storage
    func syncUserContent() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ VideoSyncService: No user logged in")
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        print("🔄 VideoSyncService: Starting sync for user: \(userId)")
        
        // 1. Get all projects for the user
        let projectsQuery = db.collection("projects")
            .whereField("author_id", isEqualTo: userId)
            .whereField("is_deleted", isEqualTo: false)
        print("🔍 VideoSyncService: Querying Firestore with: author_id=\(userId), is_deleted=false")
        
        let projects = try await projectsQuery.getDocuments()
        print("📊 VideoSyncService: Found \(projects.documents.count) projects in Firestore")
        
        // 2. Process each project
        for doc in projects.documents {
            let projectId = doc.documentID
            print("\n📦 VideoSyncService: Processing project: \(projectId)")
            print("📄 VideoSyncService: Project data: \(doc.data())")
            
            // Get project data
            let data = doc.data()
            guard let mainVideoId = data["main_video_id"] as? String else {
                print("⚠️ VideoSyncService: No main video ID for project: \(projectId)")
                continue
            }
            
            // Create project directory structure
            let docsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let projectFolder = docsURL.appendingPathComponent("LocalProjects/\(projectId)", isDirectory: true)
            let videosFolder = projectFolder.appendingPathComponent("videos", isDirectory: true)
            
            print("📂 VideoSyncService: Creating directories:")
            print("   Project: \(projectFolder.path)")
            print("   Videos: \(videosFolder.path)")
            
            try FileManager.default.createDirectory(at: videosFolder, withIntermediateDirectories: true)
            
            // 3. Download and store main video
            print("📥 VideoSyncService: Downloading main video: \(mainVideoId)")
            let mainVideoRef = storage.reference().child("videos/original/\(mainVideoId).mov")
            let mainLocalURL = videosFolder.appendingPathComponent("0")
            print("   From: videos/original/\(mainVideoId).mov")
            print("   To: \(mainLocalURL.path)")
            try await downloadFile(from: mainVideoRef, to: mainLocalURL)
            
            // 4. Download and store thumbnail
            print("🖼️ VideoSyncService: Downloading thumbnail")
            let thumbnailRef = storage.reference().child("videos/thumbnails/\(mainVideoId).jpg")
            let thumbnailLocalURL = projectFolder.appendingPathComponent("thumbnail.jpeg")
            print("   From: videos/thumbnails/\(mainVideoId).jpg")
            print("   To: \(thumbnailLocalURL.path)")
            try await downloadFile(from: thumbnailRef, to: thumbnailLocalURL)
            
            // 5. Get and store segments
            print("🎬 VideoSyncService: Fetching segments for project: \(projectId)")
            let segmentsQuery = db.collection("videos")
                .whereField("project_id", isEqualTo: projectId)
                .whereField("type", isEqualTo: "segment")
            
            let segments = try await segmentsQuery.getDocuments()
            print("   Found \(segments.documents.count) segments")
            
            var localSegments: [LocalSegment] = []
            var segIndex = 1 // Start from 1 as 0 is main video
            
            for segDoc in segments.documents {
                let segmentId = segDoc.documentID
                print("\n🎯 VideoSyncService: Processing segment: \(segmentId)")
                print("   Data: \(segDoc.data())")
                
                // Download segment video
                let segmentRef = storage.reference()
                    .child("users/\(userId)/projects/\(projectId)/videos/\(segmentId).mp4")
                let segmentLocalURL = videosFolder.appendingPathComponent("\(segIndex)")
                print("   From: users/\(userId)/projects/\(projectId)/videos/\(segmentId).mp4")
                print("   To: \(segmentLocalURL.path)")
                try await downloadFile(from: segmentRef, to: segmentLocalURL)
                
                // Create segment config
                let segData = segDoc.data()
                let configDict: [String: Any] = [
                    "segmentId": segmentId,
                    "startTime": segData["start_time"] as? Double ?? 0,
                    "endTime": segData["end_time"] as? Double ?? 0,
                    "order": segIndex
                ]
                
                // Save segment config
                let configURL = videosFolder.appendingPathComponent("\(segIndex)_config.json")
                print("   Saving config to: \(configURL.path)")
                try JSONSerialization.data(withJSONObject: configDict)
                    .write(to: configURL)
                
                // Add to local segments array
                let localSeg = LocalSegment(
                    segmentId: segmentId,
                    localFilePath: "videos/\(segIndex)",
                    startTime: segData["start_time"] as? Double,
                    endTime: segData["end_time"] as? Double,
                    order: segIndex
                )
                localSegments.append(localSeg)
                print("   Added segment to local array: \(localSeg)")
                segIndex += 1
            }
            
            // 6. Create and save project.json
            print("\n📝 VideoSyncService: Creating project.json")
            let localProject = LocalProject(
                projectId: projectId,
                authorId: userId,
                createdAt: (data["created_at"] as? Timestamp)?.dateValue() ?? Date(),
                isDeleted: false,
                mainVideoId: mainVideoId,
                mainVideoFilePath: "videos/0",
                mainThumbnailFilePath: "thumbnail.jpeg",
                segments: localSegments,
                serialization: data["serialization"] as? [String: AnyCodable]
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let projectJSON = try encoder.encode(localProject)
            let projectJSONPath = projectFolder.appendingPathComponent("project.json")
            print("   Saving to: \(projectJSONPath.path)")
            try projectJSON.write(to: projectJSONPath)
            print("   Project JSON saved successfully")
        }
        
        print("\n✅ VideoSyncService: Sync completed successfully")
    }
    
    private func downloadFile(from ref: StorageReference, to localURL: URL) async throws {
        print("📥 VideoSyncService: Downloading file")
        print("   From: \(ref.fullPath)")
        print("   To: \(localURL.path)")
        
        // If file already exists, remove it
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
            print("   Removed existing file")
        }
        
        // Download new file
        try await ref.write(toFile: localURL)
        print("   Download completed successfully")
    }
}
