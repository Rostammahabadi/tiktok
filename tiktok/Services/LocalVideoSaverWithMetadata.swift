import Foundation

/// Simple struct for startTime / endTime, etc.
struct VideoMetadata: Codable {
    let startTime: Double
    let endTime: Double
    // Add more fields if needed, e.g. “title”, “order”, etc.
}

class LocalVideoSaverWithMetadata {
    
    /// Saves a video from `sourceURL` into
    /// `Documents/LocalProjects/{projectId}/videos/{videoId}.mp4`,
    /// plus a `{videoId}.metadata.json`.
    ///
    /// - Parameters:
    ///   - sourceURL:  The local URL of the video (or a remote URL you downloaded).
    ///   - projectId:  The folder name under `LocalProjects`.
    ///   - videoId:    The file name for the video (like "segmentA" or a UUID).
    ///   - metadata:   A `VideoMetadata` struct containing startTime, endTime, etc.
    ///
    /// - Returns: The final local `URL` to the copied video file.
    /// - Throws: An error if copying the video or writing metadata fails.
    func saveVideoWithMetadata(
        from sourceURL: URL,
        projectId: String,
        videoId: String,
        metadata: VideoMetadata
    ) throws -> URL {
        
        // 1) Resolve: Documents/LocalProjects/{projectId}/videos
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let projectFolderURL = documentsURL
            .appendingPathComponent("LocalProjects")
            .appendingPathComponent(projectId)
        let videosFolderURL = projectFolderURL.appendingPathComponent("videos")
        
        // Create subfolders if needed
        try FileManager.default.createDirectory(
            at: videosFolderURL,
            withIntermediateDirectories: true
        )
        
        // 2) The final .mp4 path is {videoId}.mp4
        let videoFileName = "\(videoId).mp4"
        let videoDestURL = videosFolderURL.appendingPathComponent(videoFileName)
        
        // The metadata file is {videoId}.metadata.json
        let metadataFileName = "\(videoId).metadata.json"
        let metadataDestURL = videosFolderURL.appendingPathComponent(metadataFileName)
        
        // 3) Remove old files if they already exist
        if FileManager.default.fileExists(atPath: videoDestURL.path) {
            try FileManager.default.removeItem(at: videoDestURL)
        }
        if FileManager.default.fileExists(atPath: metadataDestURL.path) {
            try FileManager.default.removeItem(at: metadataDestURL)
        }
        
        // 4) Copy the video from source to the final path
        try FileManager.default.copyItem(at: sourceURL, to: videoDestURL)
        
        // 5) Write metadata as JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(metadata)
        try jsonData.write(to: metadataDestURL)
        
        print("✅ Saved video at: \(videoDestURL.path)")
        print("✅ Saved metadata at: \(metadataDestURL.path)")
        
        return videoDestURL
    }
    
    
    /// Loads the metadata for `videoId` in the same directory structure:
    /// `Documents/LocalProjects/{projectId}/videos/{videoId}.metadata.json`
    ///
    /// - Parameters:
    ///   - projectId: Folder under `LocalProjects`
    ///   - videoId: The base file name for the video
    /// - Returns: `VideoMetadata` if found, else nil
    func loadMetadata(projectId: String, videoId: String) -> VideoMetadata? {
        do {
            let documentsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            
            let metadataFileName = "\(videoId).metadata.json"
            let metadataURL = documentsURL
                .appendingPathComponent("LocalProjects")
                .appendingPathComponent(projectId)
                .appendingPathComponent("videos")
                .appendingPathComponent(metadataFileName)
            
            guard FileManager.default.fileExists(atPath: metadataURL.path) else {
                print("❌ No metadata file found at \(metadataURL.path)")
                return nil
            }
            
            let data = try Data(contentsOf: metadataURL)
            let metadata = try JSONDecoder().decode(VideoMetadata.self, from: data)
            print("✅ Loaded metadata for \(videoId): \(metadata)")
            return metadata
            
        } catch {
            print("❌ Error loading metadata: \(error.localizedDescription)")
            return nil
        }
    }
}
