import UIKit
import VideoEditorSDK
import FirebaseAuth

class SaveVideoToLocalURL {
    
    /// Saves the final main video + segments locally in the requested folder structure:
    ///  - /Documents/LocalProjects/{projectId}/project.json
    ///  - /Documents/LocalProjects/{projectId}/thumbnail.jpeg
    ///  - /Documents/LocalProjects/{projectId}/videos/0     // main video
    ///  - /Documents/LocalProjects/{projectId}/videos/0_config.json
    ///  - /Documents/LocalProjects/{projectId}/videos/1     // first segment
    ///  - /Documents/LocalProjects/{projectId}/videos/1_config.json
    ///  and so forth...
    ///
    /// - Parameters:
    ///   - mainVideoURL: final .mov from PESDK
    ///   - result: PESDK `VideoEditorResult` with segments
    ///   - serializedData: optional JSON from the editor (serialization)
    ///   - projectId: folder name under /Documents/LocalProjects
    func saveEditedVideoWithSegmentsLocally(
        mainVideoURL: URL,
        result: VideoEditorResult,
        serializedData: Data?,
        projectId: String
    ) async throws {
        
        let authorId = Auth.auth().currentUser?.uid ?? "LocalUserID-12345"
        
        // 1) Prepare subfolders
        let docsURL = try FileManager.default.url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        let projectFolder = docsURL.appendingPathComponent("LocalProjects/\(projectId)", isDirectory: true)
        let videosFolder = projectFolder.appendingPathComponent("videos", isDirectory: true)
        
        try FileManager.default.createDirectory(at: videosFolder, withIntermediateDirectories: true)
        
        // 2) Export + store the main video at "videos/0"
        let mainIndex = 0
        let mainVideoId = "videoMain-\(UUID().uuidString)"
        let mainExportedURL = try await exportVideo(from: mainVideoURL, fileType: .mov)
        
        let mainVideoDest = videosFolder.appendingPathComponent("\(mainIndex)") // no extension
        if FileManager.default.fileExists(atPath: mainVideoDest.path) {
            try FileManager.default.removeItem(at: mainVideoDest)
        }
        try FileManager.default.copyItem(at: mainExportedURL, to: mainVideoDest)
        
        // 3) (Optional) Write a JSON metadata for the main video at "0_config.json"
        let mainVideoConfig = [
            "id": mainVideoId,
            "fileName": "0",
            "startTime": 0,
            "endTime": 0
        ] as [String : Any]
        
        let mainConfigURL = videosFolder.appendingPathComponent("\(mainIndex)_config.json")
        try writeJSON(mainVideoConfig, to: mainConfigURL)
        
        // 4) Export + store segments at "videos/{i}"
        var localSegments: [LocalSegment] = []
        var segIndex = 1 // first segment is “1”, second is “2”, etc.
        
        for seg in result.task.video.segments {
            // Export segment to mp4
            let mp4URL = try await exportVideo(from: seg.url, fileType: .mp4)
            
            // Copy to "videos/{segIndex}"
            let segmentFileDest = videosFolder.appendingPathComponent("\(segIndex)")
            if FileManager.default.fileExists(atPath: segmentFileDest.path) {
                try FileManager.default.removeItem(at: segmentFileDest)
            }
            try FileManager.default.copyItem(at: mp4URL, to: segmentFileDest)
            
            // Write a “_config.json” next to it
            let configDest = videosFolder.appendingPathComponent("\(segIndex)_config.json")
            let segConfigDict: [String: Any] = [
                "segmentId": "segment-\(UUID().uuidString)",
                "startTime": seg.startTime ?? 0,
                "endTime": seg.endTime ?? 0,
                "order": segIndex
            ]
            try writeJSON(segConfigDict, to: configDest)
            
            // Add to our in-memory array
            let localSeg = LocalSegment(
                segmentId: "segment-\(segIndex)",
                localFilePath: "videos/\(segIndex)", // relative path
                startTime: seg.startTime,
                endTime: seg.endTime,
                order: segIndex
            )
            localSegments.append(localSeg)
            print("Saved segment: \(localSeg)")
            segIndex += 1
        }
        
        // 5) Optional: generate + store a single “thumbnail.jpeg” in the project root
        let mainThumbData = try? await generateThumbnail(from: mainExportedURL)
        var thumbnailFilePath: String? = nil
        if let data = mainThumbData {
            let thumbURL = projectFolder.appendingPathComponent("thumbnail.jpeg")
            if FileManager.default.fileExists(atPath: thumbURL.path) {
                try FileManager.default.removeItem(at: thumbURL)
            }
            try data.write(to: thumbURL)
            thumbnailFilePath = "thumbnail.jpeg"
        }
        
        // 6) Build the LocalProject object
        var localProj = LocalProject(
            projectId: projectId,
            authorId: authorId,
            createdAt: Date(),
            isDeleted: false,
            mainVideoId: mainVideoId,
            mainVideoFilePath: "videos/\(mainIndex)", // e.g. “videos/0”
            mainThumbnailFilePath: thumbnailFilePath,
            segments: localSegments,
            serialization: nil
        )
        
        // If we have PESDK serialization data, store it in `serialization` field
        if let serializedData = serializedData,
           let jsonObj = try? JSONSerialization.jsonObject(with: serializedData, options: []) {
            localProj.serialization = ["data": AnyCodable(jsonObj)]
        }
        
        // 7) Write the `LocalProject` as JSON at “project.json”
        let projectJSONURL = projectFolder.appendingPathComponent("project.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let encodedProj = try encoder.encode(localProj)
        
        if FileManager.default.fileExists(atPath: projectJSONURL.path) {
            try FileManager.default.removeItem(at: projectJSONURL)
        }
        try encodedProj.write(to: projectJSONURL)
        
        print("✅ Successfully stored project locally at: \(projectFolder.path)")
    }
    
    
    // MARK: - Helper: Export Video
    
    private func exportVideo(from sourceURL: URL, fileType: AVFileType) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        try await asset.load(.tracks, .duration)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "SaveVideoToLocalURL", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create export session"
            ])
        }
        
        let extStr = (fileType == .mp4) ? ".mp4" : ".mov"
        let tempOutputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + extStr)
        
        exportSession.outputURL = tempOutputURL
        exportSession.outputFileType = fileType
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(
                domain: "SaveVideoToLocalURL",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey:
                           "Export failed with status: \(exportSession.status.rawValue)"]
            )
        }
        
        return tempOutputURL
    }
    
    
    // MARK: - Helper: Write JSON

    private func writeJSON(_ dict: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try data.write(to: url)
    }
    
    
    // MARK: - Helper: Generate Thumbnail
    
    private func generateThumbnail(from videoURL: URL) async throws -> Data? {
        let asset = AVURLAsset(url: videoURL)
        try await asset.load(.tracks)
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.7)
    }
}
