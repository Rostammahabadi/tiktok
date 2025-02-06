import UIKit
import VideoEditorSDK
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions
import FirebaseCore
import AVFoundation
import FirebaseAuth

class SaveVideoToRemoteURL: NSObject {
    weak var presentingViewController: UIViewController?
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    func uploadVideo(from url: URL, result: VideoEditorResult) {
        // Get current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            return
        }
        
        let videoId = UUID().uuidString
        let originalPath = "videos/original/\(videoId).mp4"
        let videoRef = storage.reference().child(originalPath)
        
        print("📤 Starting upload for video: \(videoId)")
        
        // Generate thumbnail
        Task {
            let thumbnailPath = "videos/thumbnails/\(videoId).jpg"
            let thumbnailRef = storage.reference().child(thumbnailPath)
            
            if let thumbnailData = try? await generateThumbnail(from: url) {
                // Upload thumbnail
                _ = thumbnailRef.putData(thumbnailData, metadata: nil)
                let thumbnailURL = try? await thumbnailRef.downloadURL()
                
                // Upload video
                videoRef.putFile(from: url, metadata: nil) { metadata, error in
                    if let error = error {
                        print("❌ Upload error: \(error.localizedDescription)")
                        return
                    }
                    
                    print("✅ Upload complete, getting download URL")
                    videoRef.downloadURL { downloadURL, error in
                        if let error = error {
                            print("❌ Download URL error: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let downloadURL = downloadURL else {
                            print("❌ Download URL is nil")
                            return
                        }
                        
                        print("✅ Got download URL: \(downloadURL.absoluteString)")
                        let videoData: [String: Any] = [
                            "originalUrl": downloadURL.absoluteString,
                            "originalPath": originalPath,
                            "thumbnailUrl": thumbnailURL?.absoluteString,
                            "thumbnailPath": thumbnailPath,
                            "createdAt": Timestamp(date: Date()),
                            "status": "processing",
                            "authorId": userId,
                            "title": "Video \(videoId.prefix(6))",
                            "description": "Created on \(Date())",
                            "likes": 0,
                            "views": 0
                        ]
                        
                        print("💾 Saving to Firestore...")
                        self.db.collection("videos").document(videoId).setData(videoData) { error in
                            if let error = error {
                                print("❌ Firestore error: \(error.localizedDescription)")
                                return
                            }
                            
                            print("✅ Saved video metadata to Firestore")
                            self.convertToHLS(filePath: originalPath, videoId: videoId)
                        }
                    }
                }
            }
        }
    }
    
    // Add thumbnail generation function
    private func generateThumbnail(from videoURL: URL) async throws -> Data? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Get thumbnail from first frame
        let time = CMTime(seconds: 0, preferredTimescale: 1)
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        let uiImage = UIImage(cgImage: cgImage)
        
        // Convert to JPEG data with 0.8 quality
        return uiImage.jpegData(compressionQuality: 0.8)
    }
    
    func convertToHLS(filePath: String, videoId: String) {
        print("🎬 Starting HLS conversion for video: \(videoId)")
        
        // First get the document from Firestore
        db.collection("videos").document(videoId).getDocument { (document, error) in
            if let error = error {
                print("❌ Firestore error: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists, let originalPath = document.get("originalPath") as? String else {
                print("❌ Document doesn't exist or missing originalPath")
                return
            }
            
            guard let projectID = FirebaseApp.app()?.options.projectID else {
                print("❌ Could not get Firebase project ID")
                return
            }
            
            let functionRegion = "us-central1"
            let functionURL = "https://\(functionRegion)-\(projectID).cloudfunctions.net/convertVideoToHLS"
            
            guard let url = URL(string: functionURL) else {
                print("❌ Invalid function URL")
                return
            }
            
            print("🌐 Function URL: \(functionURL)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody: [String: Any] = ["filePath": originalPath]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "Invalid JSON"
                print("📦 Sending JSON: \(jsonString)")  // ✅ Debug log to verify request structure
                request.httpBody = jsonData
            } catch {
                print("❌ Failed to serialize request body: \(error.localizedDescription)")
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    return
                }
                
                print("📡 Response status code: \(httpResponse.statusCode)")
                
                guard let data = data else {
                    print("❌ No data received")
                    return
                }
                
                do {
                    if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📦 Response data: \(responseJSON)")
                        
                        if httpResponse.statusCode == 200 {
                            if let hlsPath = responseJSON["hlsPath"] as? String,
                               let hlsURL = responseJSON["hlsURL"] as? String {
                                print("✅ HLS conversion successful")
                                
                                let updateData: [String: Any] = [
                                    "status": "completed",
                                    "hlsPath": "\(hlsPath)/output.m3u8",
                                    "hlsUrl": hlsURL,
                                    "type": "hls"
                                ]
                                
                                self.db.collection("videos").document(videoId).updateData(updateData) { error in
                                    if let error = error {
                                        print("❌ Failed to update video with HLS info: \(error.localizedDescription)")
                                    } else {
                                        print("✅ Updated video with HLS information")
                                    }
                                }
                            } else {
                                print("❌ Missing HLS information in response")
                            }
                        } else {
                            let errorMessage = (responseJSON["error"] as? String) ?? "Unknown error"
                            print("❌ Function error: \(errorMessage)")
                        }
                    }
                } catch {
                    print("❌ Failed to parse response: \(error.localizedDescription)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📝 Raw response: \(responseString)")
                    }
                }
            }
            
            task.resume()  // ✅ Ensuring network request runs
        }
    }
}
