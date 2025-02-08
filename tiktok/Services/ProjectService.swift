import Foundation
import FirebaseFirestore
import FirebaseAuth

class ProjectService {
    static let shared = ProjectService()
    private let db = Firestore.firestore()
    private let projectsCollection = "projects"
    private let videosCollection = "videos"
    
    private init() {}
    
    // MARK: - Create
    
    func createProject(title: String, description: String? = nil, thumbnailUrl: String? = nil) async throws -> Project {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot create project: User not authenticated")
            throw NSError(domain: "ProjectService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("📝 Creating project with title: \(title)")
        
        // Generate a new document ID
        let docRef = db.collection(projectsCollection).document()
        
        let project = Project(
            id: docRef.documentID,
            authorId: userId,
            title: title,
            description: description,
            thumbnailUrl: thumbnailUrl,
            status: .created,
            isDeleted: false
        )
        
        do {
            // Create a dictionary with the project data
            var data: [String: Any] = [
                "author_id": userId,
                "title": title,
                "status": Project.ProjectStatus.created.rawValue,
                "is_deleted": false
            ]
            
            if let description = description {
                data["description"] = description
            }
            
            if let thumbnailUrl = thumbnailUrl {
                data["thumbnail_url"] = thumbnailUrl
            }
            
            // Set the data with merge to allow server timestamp
            try await docRef.setData(data, merge: true)
            
            print("✅ Project created successfully")
            print("✅ Document ID: \(docRef.documentID)")
            return project
        } catch {
            print("❌ Failed to create project: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Read
    
    func getProject(_ projectId: String) async throws -> Project {
        print("📝 Fetching project: \(projectId)")
        
        let docRef = db.collection(projectsCollection).document(projectId)
        let document = try await docRef.getDocument()
        
        guard let project = try? document.data(as: Project.self) else {
            print("❌ Project not found or failed to decode")
            throw NSError(domain: "ProjectService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        print("✅ Successfully retrieved project")
        return project
    }
    
    /// Fetch all projects for the current user
    /// - Returns: Array of projects
    func fetchUserProjects() async throws -> [Project] {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot fetch projects: User not authenticated")
            throw NSError(domain: "ProjectService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("📥 Fetching projects for user: \(userId)")
        
        do {
            let snapshot = try await db.collection(projectsCollection)
                .whereField("author_id", isEqualTo: userId)
                .order(by: "created_at", descending: true)
                .getDocuments()
            
            let projects = snapshot.documents.compactMap { document -> Project? in
                let data = document.data()
                
                return Project(
                    id: document.documentID,
                    authorId: data["author_id"] as? String ?? "",
                    title: data["title"] as? String ?? "",
                    description: data["description"] as? String,
                    thumbnailUrl: data["thumbnail_url"] as? String,
                    status: Project.ProjectStatus(rawValue: data["status"] as? String ?? "") ?? .created,
                    serializedSettings: {
                        if let serialization = data["serialization"] as? [String: Any] {
                            return try? JSONSerialization.data(withJSONObject: serialization)
                        }
                        return nil
                    }(),
                    isDeleted: data["is_deleted"] as? Bool ?? false,
                    createdAt: (data["created_at"] as? Timestamp)?.dateValue()
                )
            }
            
            print("✅ Fetched \(projects.count) projects")
            return projects
        } catch {
            print("❌ Failed to fetch projects: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getUserProjects() async throws -> [Project] {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot get user projects: User not authenticated")
            throw NSError(domain: "ProjectService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("📝 Fetching projects for user: \(userId)")
        
        let snapshot = try await db.collection(projectsCollection)
            .whereField("author_id", isEqualTo: userId)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        print("✅ Successfully retrieved user projects")
        return try snapshot.documents.compactMap { document in
            try document.data(as: Project.self)
        }
    }
    
    func fetchProject(_ projectId: String) async throws -> Project {
        print("📝 Fetching project: \(projectId)")
        
        let doc = try await db.collection("projects").document(projectId).getDocument()
        guard let data = doc.data() else {
            print("❌ Project not found: \(projectId)")
            throw NSError(domain: "ProjectService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        print("📄 Project data: \(data)")
        
        // Convert serialization dictionary to Data
        var serializedSettings: Data?
        if let serialization = data["serialization"] as? [String: Any] {
            serializedSettings = try? JSONSerialization.data(withJSONObject: serialization)
            print("✅ Successfully converted serialization to Data")
        } else {
            print("⚠️ No serialization data found")
        }
        
        let project = Project(
            id: doc.documentID,
            authorId: data["author_id"] as? String ?? "",
            title: data["title"] as? String ?? "",
            description: data["description"] as? String,
            thumbnailUrl: data["thumbnail_url"] as? String,
            status: Project.ProjectStatus(rawValue: data["status"] as? String ?? "") ?? .created,
            serializedSettings: serializedSettings,
            isDeleted: data["is_deleted"] as? Bool ?? false,
            createdAt: (data["created_at"] as? Timestamp)?.dateValue()
        )
        
        print("✅ Created project object: \(project.id ?? "unknown")")
        return project
    }
    
    func fetchProjectVideos(projectId: String) async throws -> [Video] {
        print("📝 Fetching videos for project: \(projectId)")
        
        let snapshot = try await db.collection(videosCollection)
            .whereField("project_id", isEqualTo: projectId)
            .order(by: "order", descending: false)
            .getDocuments()
        
        let videos = try snapshot.documents.map { document -> Video in
            let data = document.data()
            
            return Video(
                id: document.documentID,
                authorId: data["author_id"] as? String ?? "",
                projectId: data["project_id"] as? String ?? "",
                url: data["url"] as? String ?? "",
                storagePath: data["storagePath"] as? String ?? "",
                startTime: data["startTime"] as? Double,
                endTime: data["endTime"] as? Double,
                order: data["order"] as? Int ?? 0,
                isDeleted: data["is_deleted"] as? Bool ?? false
            )
        }
        
        print("✅ Found \(videos.count) videos")
        return videos
    }
    
    // MARK: - Update
    
    func updateProject(_ projectId: String, title: String? = nil, description: String? = nil, status: Project.ProjectStatus? = nil) async throws {
        print("📝 Updating project: \(projectId)")
        
        var updateData: [String: Any] = [:]
        
        if let title = title {
            updateData["title"] = title
        }
        if let description = description {
            updateData["description"] = description
        }
        if let status = status {
            updateData["status"] = status.rawValue
        }
        
        guard !updateData.isEmpty else {
            print("❌ No updates to apply")
            return
        }
        
        do {
            try await db.collection(projectsCollection)
                .document(projectId)
                .updateData(updateData)
            print("✅ Project updated successfully")
        } catch {
            print("❌ Failed to update project: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Delete
    
    func markProjectAsDeleted(_ projectId: String) async throws {
        print("📝 Deleting project: \(projectId)")
        
        do {
            try await db.collection(projectsCollection)
                .document(projectId)
                .updateData(["is_deleted" : true])
            print("✅ Project deleted successfully")
        } catch {
            print("❌ Failed to delete project: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Listeners
    
    func addProjectListener(_ projectId: String, completion: @escaping (Result<Project, Error>) -> Void) -> ListenerRegistration {
        print("📝 Adding project listener for project: \(projectId)")
        
        return db.collection(projectsCollection)
            .document(projectId)
            .addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    print("❌ Project listener error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let document = documentSnapshot else {
                    print("❌ Project document not found")
                    completion(.failure(NSError(domain: "ProjectService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document not found"])))
                    return
                }
                
                do {
                    let project = try document.data(as: Project.self)
                    print("✅ Project listener received update")
                    completion(.success(project))
                } catch {
                    print("❌ Failed to decode project: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
    }
}
