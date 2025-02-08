import Foundation

class LocalProjectService {
    static let shared = LocalProjectService()
    private init() {}
    
    /// Load the LocalProject from /Documents/LocalProjects/{projectId}/project.json
    func loadLocalProject(projectId: String) throws -> LocalProject {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let folderURL = docs.appendingPathComponent("LocalProjects/\(projectId)", isDirectory: true)
        let projectFile = folderURL.appendingPathComponent("project.json")
        
        guard FileManager.default.fileExists(atPath: projectFile.path) else {
            throw NSError(domain: "LocalProjectService", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "No local project found for \(projectId)"
            ])
        }
        let data = try Data(contentsOf: projectFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let localProj = try decoder.decode(LocalProject.self, from: data)
        return localProj
    }
    
    /// Resolve a relative path against the project directory
    func resolvePath(_ relativePath: String, projectId: String) -> URL {
        let docs = try! FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let projectBaseURL = docs.appendingPathComponent("LocalProjects/\(projectId)", isDirectory: true)
        return projectBaseURL.appendingPathComponent(relativePath)
    }
    
    /// Convert each LocalSegment into your domain `Video` object and return serialized settings
    /// Only returns segment videos, not the main video
    func loadAndPrepareVideosLocally(projectId: String) async throws -> (videos: [Video], serializedSettings: Data?) {
        let localProject = try loadLocalProject(projectId: projectId)
        
        // Convert serialization from [String: AnyCodable]? to Data?
        let serializedSettings: Data?
        if let serialization = localProject.serialization,
           let dataDict = serialization["data"]?.value as? [String: Any] {
            serializedSettings = try? JSONSerialization.data(withJSONObject: dataDict)
        } else {
            serializedSettings = nil
        }
        
        // Only convert and return the segments
        let videos = localProject.segments.map { seg in
            Video(
                id: seg.segmentId,
                authorId: localProject.authorId,
                projectId: projectId,
                url: resolvePath(seg.localFilePath, projectId: projectId).absoluteString,
                storagePath: seg.localFilePath,
                startTime: seg.startTime,
                endTime: seg.endTime,
                order: seg.order,
                isDeleted: false
            )
        }
        
        return (videos: videos, serializedSettings: serializedSettings)
    }
    
    /// Load all local projects from /Documents/LocalProjects/
    func loadAllLocalProjects() async throws -> [Project] {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let localProjectsDir = docs.appendingPathComponent("LocalProjects", isDirectory: true)
        
        // Get all subdirectories in LocalProjects (each is a project)
        let contents = try FileManager.default.contentsOfDirectory(
            at: localProjectsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        // Load each project
        var projects: [Project] = []
        for projectDir in contents {
            let projectId = projectDir.lastPathComponent
            if let localProject = try? loadLocalProject(projectId: projectId) {
                // Convert LocalProject to Project
                let project = Project(
                    id: localProject.projectId,
                    authorId: localProject.authorId,
                    title: "Local Project",
                    description: nil,
                    thumbnailUrl: localProject.mainThumbnailFilePath,
                    status: .created,
                    serializedSettings: {
                        if let serialization = localProject.serialization,
                           let dataDict = serialization["data"]?.value as? [String: Any] {
                            return try? JSONSerialization.data(withJSONObject: dataDict)
                        }
                        return nil
                    }(),
                    isDeleted: localProject.isDeleted,
                    createdAt: localProject.createdAt
                )
                projects.append(project)
            }
        }
        
        return projects
    }
}
