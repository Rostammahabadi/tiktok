//
//  VideoCache.swift
//  tiktok
//
//  Created by Rostam on 2/4/25.
//

// VideoCache.swift
import Foundation

class VideoCache {
    static let shared = VideoCache()
    private let cache = NSCache<NSString, NSData>()
    
    func cache(data: Data, for key: String) {
        cache.setObject(data as NSData, forKey: key as NSString)
    }
    
    func getData(for key: String) -> Data? {
        return cache.object(forKey: key as NSString) as Data?
    }
}
