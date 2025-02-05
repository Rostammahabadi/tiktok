import UIKit
import VideoEditorSDK
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions

class SaveVideoToRemoteURL: NSObject {
    weak var presentingViewController: UIViewController?
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    func uploadVideo(from url: URL, result: VideoEditorResult) {
        let videoId = UUID().uuidString
        let originalPath = "videos/original/\(videoId).mp4"
        let videoRef = storage.reference().child(originalPath)
        
        print("📤 Starting upload for video: \(videoId)")
        
        // Create a strong reference to self for the upload chain
        let strongSelf = self
        
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
                    "createdAt": Timestamp(date: Date()),
                    "status": "processing"
                ]
                
                print("💾 Saving to Firestore...")
                // Use strongSelf here to ensure we maintain the reference
                strongSelf.db.collection("videos").document(videoId).setData(videoData) { error in
                    if let error = error {
                        print("❌ Firestore write error: \(error.localizedDescription)")
                        return
                    }
                    
                    print("✅ Video saved to Firestore successfully")
                    // Start HLS conversion
                    strongSelf.convertToHLS(filePath: originalPath, videoId: videoId)
                }
            }
        }
    }
    
    func convertToHLS(filePath: String, videoId: String) {
        print("🎬 Starting HLS conversion for video: \(videoId)")
        
        // Create strong reference to self at the beginning
        let strongSelf = self
        let functions = Functions.functions()
        let payload: [String: Any] = ["filePath": filePath]
        
        print("☁️ Calling Cloud Function with payload: \(payload)")
        
        functions.httpsCallable("convertVideoToHLS").call(payload) { result, error in
            print("⬇️ Received response from Cloud Function")
            
            if let error = error as NSError? {
                print("❌ HLS Conversion Error: \(error.localizedDescription)")
                print("❌ Error domain: \(error.domain)")
                print("❌ Error code: \(error.code)")
                if let details = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any] {
                    print("❌ Error details: \(details)")
                }
                strongSelf.updateVideoStatus(videoId: videoId, status: "failed", error: error.localizedDescription)
                return
            }
            
            // Log the raw result data
            print("📦 Raw result data: \(String(describing: result?.data))")
            
            guard let resultData = result?.data else {
                print("❌ No data received from Cloud Function")
                strongSelf.updateVideoStatus(videoId: videoId, status: "failed", error: "No data received from Cloud Function")
                return
            }
            
            // Print the type of resultData to help debug
            print("📝 Result data type: \(type(of: resultData))")
            
            guard let data = resultData as? [String: Any] else {
                print("❌ Could not cast result data to [String: Any]")
                print("❌ Actual data received: \(resultData)")
                strongSelf.updateVideoStatus(videoId: videoId, status: "failed", error: "Invalid response format")
                return
            }
            
            // Print all keys in the data dictionary
            print("🔑 Available keys in response: \(data.keys.joined(separator: ", "))")
            
            guard let hlsPath = data["hlsPath"] as? String else {
                print("❌ Missing hlsPath in response")
                print("❌ Available data: \(data)")
                strongSelf.updateVideoStatus(videoId: videoId, status: "failed", error: "Missing hlsPath")
                return
            }
            
            guard let hlsURL = data["hlsURL"] as? String else {
                print("❌ Missing hlsURL in response")
                print("❌ Available data: \(data)")
                strongSelf.updateVideoStatus(videoId: videoId, status: "failed", error: "Missing hlsURL")
                return
            }
            
            print("✅ Successfully parsed Cloud Function response")
            print("📍 HLS Path: \(hlsPath)")
            print("🔗 HLS URL: \(hlsURL)")
            
            let updateData: [String: Any] = [
                "status": "completed",
                "hlsPath": "\(hlsPath)/output.m3u8",
                "hlsUrl": hlsURL,
                "type": "hls"
            ]
            
            print("📝 Attempting to update Firestore with data: \(updateData)")
            
            // Update Firestore document with HLS information
            let docRef = strongSelf.db.collection("videos").document(videoId)
            docRef.updateData(updateData) { updateError in
                if let updateError = updateError {
                    print("❌ Failed to update video with HLS info: \(updateError.localizedDescription)")
                    print("❌ Error domain: \(updateError._domain)")
                    print("❌ Error code: \(updateError._code)")
                    strongSelf.updateVideoStatus(videoId: videoId, status: "failed", error: "Failed to save HLS information")
                } else {
                    print("✅ Updated video with HLS information")
                    // Verify the update
                    docRef.getDocument { document, verifyError in
                        if let verifyError = verifyError {
                            print("❌ Failed to verify update: \(verifyError.localizedDescription)")
                        } else if let document = document, document.exists {
                            print("✅ Verified HLS update in Firestore")
                            print("📄 Updated document data: \(document.data() ?? [:])")
                            print("🎉 Video processing completed successfully")
                        } else {
                            print("❌ Document not found after update")
                        }
                    }
                }
            }
        }
    }
    
    private func updateVideoStatus(videoId: String, status: String, error: String?) {
        var updateData: [String: Any] = ["status": status]
        if let error = error {
            updateData["error"] = error
        }
        
        db.collection("videos").document(videoId).updateData(updateData) { error in
            if let error = error {
                print("❌ Status update error: \(error.localizedDescription)")
            } else {
                print("✅ Status updated to: \(status)")
            }
        }
    }
}
