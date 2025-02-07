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
    
    /// Convert each LocalSegment into your domain `Video` object
    /// Only returns segment videos, not the main video
    func loadAndPrepareVideosLocally(projectId: String) async throws -> [Video] {
        let localProject = try loadLocalProject(projectId: projectId)
        
        // Only convert and return the segments
        return localProject.segments.map { seg in
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
    }
}
