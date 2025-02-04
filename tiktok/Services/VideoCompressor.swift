import AVFoundation
import VideoToolbox

enum VideoCompressorError: Error {
    case exportFailed
    case invalidInput
    case compressionFailed(String)
}

actor VideoCompressor {
    func compressVideo(inputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetMediumQuality // Using a preset instead of manual settings
        ) else {
            throw VideoCompressorError.exportFailed
        }
        
        // Setup output URL in temp directory
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Create video composition to control output size
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: 1080, height: 1920) // 1080p
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30fps
        
        // Apply video composition
        exportSession.videoComposition = videoComposition
        
        // Export the video
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw VideoCompressorError.compressionFailed(
                exportSession.error?.localizedDescription ?? "Unknown error"
            )
        }
        
        return outputURL
    }
} 