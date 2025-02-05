import UIKit
import VideoEditorSDK
import FirebaseStorage
import FirebaseFunctions

class SaveVideoToRemoteURL: NSObject {
    weak var presentingViewController: UIViewController?
    
    func uploadVideo(from url: URL, result: VideoEditorResult) {
        print("🎬 Starting video upload process...")

        let storageRef = Storage.storage().reference()
        let fileName = "\(UUID().uuidString).mp4"
        let videoRef = storageRef.child("videos/\(fileName)")

        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"

        videoRef.putFile(from: url, metadata: metadata) { metadata, error in
            if let error = error {
                print("❌ Upload error: \(error.localizedDescription)")
                return
            }

            print("✅ Upload complete! Metadata: \(String(describing: metadata))")

            // Get the video URL path
            videoRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Error getting download URL: \(error.localizedDescription)")
                    return
                }

                if let downloadURL = url {
                    print("🌍 Video uploaded to: \(downloadURL.absoluteString)")
                    
                    // ✅ Call Firebase Function to convert to HLS
                    self.convertToHLS(filePath: "videos/\(fileName)")
                }
            }

            // Clean up local file after successful upload
            if result.status != .passedWithoutRendering {
                try? FileManager.default.removeItem(at: url)
                print("🧹 Cleaned up local file after upload")
            }
        }

        print("🚀 Upload task started")
    }

    func convertToHLS(filePath: String) {
        print("🎬 Requesting HLS conversion for \(filePath)...")
        
        let functions = Functions.functions()
        functions.httpsCallable("convertVideoToHLS").call(["filePath": filePath]) { result, error in
            if let error = error {
                print("❌ HLS Conversion Error: \(error.localizedDescription)")
                return
            }

            if let data = result?.data as? [String: Any],
               let hlsURL = data["hlsURL"] as? String {
                print("✅ HLS Ready: \(hlsURL)")
                
                // You can now use hlsURL to stream the video in your app
            }
        }
    }
    
    func videoEditViewControllerShouldStart(_ videoEditViewController: VideoEditViewController, task: VideoEditorTask) -> Bool {
        print("🎬 Starting video editor task: \(task)")
        return true
    }
    
    func videoEditViewControllerDidFinish(_ videoEditViewController: VideoEditViewController, result: VideoEditorResult) {
        print("✅ Video editor finished. Status: \(result.status)")
        print("📝 Output URL: \(result.output.url)")
        
        guard let presentingVC = presentingViewController else {
            print("❌ Error: presentingViewController is nil")
            return
        }
        
        Task {
            do {
                await uploadVideo(from: result.output.url, result: result)
            } catch {
                print("❌ Error processing video: \(error.localizedDescription)")
            }
        }
    }
    
    func videoEditViewControllerDidFail(_ videoEditViewController: VideoEditViewController, error: VideoEditorError) {
        print("❌ Video editor failed: \(error.localizedDescription)")
        presentingViewController?.dismiss(animated: true)
    }
    
    func videoEditViewControllerDidCancel(_ videoEditViewController: VideoEditViewController) {
        print("🚫 Video editor cancelled")
        presentingViewController?.dismiss(animated: true)
    }
}
