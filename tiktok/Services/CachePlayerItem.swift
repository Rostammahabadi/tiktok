//
//  CachePlayerItem.swift
//  tiktok
//
//  Created by Rostam on 2/4/25.
//

// CachingPlayerItem.swift
import AVFoundation

/// A custom player item that starts downloading the remote video as soon as it’s created.
/// When the download finishes it stores the video data in the shared cache.
class CachingPlayerItem: AVPlayerItem {
    let videoURL: URL

    /// Optional: When download finishes, store the data in this property.
    var videoData: Data?

    init(url: URL) {
        self.videoURL = url
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        super.init(asset: asset, automaticallyLoadedAssetKeys: ["playable"])
        download()
    }

    /// Convenience initializer to create a player item from already cached data.
    convenience init?(data: Data, url: URL) {
        // Write the data to a temporary file and use that file URL to create an asset.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        do {
            try data.write(to: tempURL)
            self.init(url: tempURL)
        } catch {
            print("Error writing cached video to disk: \(error)")
            return nil
        }
    }

    /// Start downloading the video data.
    private func download() {
        URLSession.shared.dataTask(with: videoURL) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                print("Error downloading video: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            self.videoData = data
            // Cache the downloaded data for future use.
            VideoCache.shared.cache(data: data, for: self.videoURL.absoluteString)
        }.resume()
    }
}
