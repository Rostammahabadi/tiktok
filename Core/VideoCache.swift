import Foundation

/// A simple in-memory cache for video data
class VideoCache {
    static let shared = VideoCache()
    private let cache = NSCache<NSString, NSData>()
    
    private init() {}
    
    func cache(data: Data, for key: String) {
        cache.setObject(data as NSData, forKey: key as NSString)
    }
    
    func getData(for key: String) -> Data? {
        return cache.object(forKey: key as NSString) as Data?
    }
} 