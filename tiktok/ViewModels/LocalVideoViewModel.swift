//
//  LocalVideoViewModel.swift
//  tiktok
//
//  Created by Rostam on 2/7/25.
//
import Swift
import Foundation
struct LocalVideoViewModel {
    static let shared = LocalVideoViewModel()

    func fetchProjectVideos(_ projectId: String) async throws -> [Video] {
        // 1) Load the same localProject
        let localProject = try loadLocalProjectJSON(projectId: projectId)
        // 2) Convert local segments into domain videos
        let videos = localProject.segments.map { mapLocalSegmentToVideo($0, projectId: projectId) }

        // Also consider adding the main video itself as a “Video” if you do that in your domain
        // For example, you might create a “mainVideo” with localProject.mainVideoFilePath, etc.

        // If you want the main final video included in the array, do something like:
        /*
        let mainVideo = Video(
            id: localProject.mainVideoId,
            url: localProject.mainVideoFilePath,   // local path
            projectId: projectId,
            startTime: nil,
            endTime: nil,
            order: -1  // or 999, or something
        )
        var combined = [mainVideo]
        combined.append(contentsOf: videos)
        return combined
        */

        return videos
    }

    private func loadLocalProjectJSON(projectId: String) throws -> LocalProject {
        // same logic as the other service
        let docs = try FileManager.default.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: false)
        let folderURL = docs.appendingPathComponent("LocalProjects/\(projectId)", isDirectory: true)
        let projectFile = folderURL.appendingPathComponent("project.json")

        guard FileManager.default.fileExists(atPath: projectFile.path) else {
            throw NSError(domain: "LocalVideoViewModel", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Project JSON not found for \(projectId)"
            ])
        }

        let data = try Data(contentsOf: projectFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let localProject = try decoder.decode(LocalProject.self, from: data)
        return localProject
    }

    private func mapLocalSegmentToVideo(_ seg: LocalSegment, projectId: String) -> Video {
        return Video(
            id: seg.segmentId,
            authorId: "",
            projectId: projectId,
            url: seg.localFilePath,  // local doc path
            storagePath: "",
            startTime: seg.startTime,
            endTime: seg.endTime,
            order: seg.order
        )
    }
}
