import Foundation
import FirebaseFirestore
import FirebaseAuth

class ProjectService {
    static let shared = ProjectService()
    private let db = Firestore.firestore()
    private let projectsCollection = "projects"
    
    private init() {}
    
    // MARK: - Create
    
    func createProject(title: String, description: String? = nil) async throws -> Project {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot create project: User not authenticated")
            throw NSError(domain: "ProjectService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("📝 Creating project with title: \(title)")
        
        let project = Project(
            authorId: userId,
            title: title,
            description: description,
            status: .created
        )
        
        do {
            // Generate a new document ID
            let docRef = db.collection(projectsCollection).document()
            
            // Create a dictionary with the project data
            var data: [String: Any] = [
                "author_id": userId,
                "title": title,
                "status": Project.ProjectStatus.created.rawValue
            ]
            
            if let description = description {
                data["description"] = description
            }
            
            // Set the data with merge to allow server timestamp
            try await docRef.setData(data, merge: true)
            
            var savedProject = project
            savedProject.id = docRef.documentID
            print("✅ Project created successfully with ID: \(docRef.documentID)")
            return savedProject
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
    
    func deleteProject(_ projectId: String) async throws {
        print("📝 Deleting project: \(projectId)")
        
        do {
            try await db.collection(projectsCollection)
                .document(projectId)
                .delete()
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
