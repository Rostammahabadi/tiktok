//
//  LocalProject.swift
//  tiktok
//
//  Created by Rostam on 2/7/25.
//

import Foundation

/// Represents a local project stored on the device.
struct LocalProject: Codable {
    let projectId: String
    let authorId: String
    let createdAt: Date
    
    // The main video info
    var mainVideoId: String
    var mainVideoFilePath: String
    var mainThumbnailFilePath: String? // optional if you save a local JPG
    
    // The list of segment video info
    var segments: [LocalSegment]
    
    // Optional: storing editor serialization
    var serialization: [String: AnyCodable]? // use a flexible wrapper for JSON
}

/// A local “segment” that references a saved .mp4 file + metadata.
struct LocalSegment: Codable {
    let segmentId: String
    let localFilePath: String
    let startTime: Double?
    let endTime: Double?
    let order: Int
}

/// A wrapper type to store any JSON
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // We can decode multiple types, but for simplicity, we just store them as raw JSON
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let str = try? container.decode(String.self) {
            value = str
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else {
            value = "Unknown"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            let nested = dict.mapValues { AnyCodable($0) }
            try container.encode(nested)
        case let array as [Any]:
            let nested = array.map { AnyCodable($0) }
            try container.encode(nested)
        case let str as String:
            try container.encode(str)
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        default:
            let description = String(describing: value)
            try container.encode(description)
        }
    }
}
