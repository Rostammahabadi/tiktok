import UIKit
import VideoEditorSDK

class SwipeDismissalController: UIViewController {
    private let cameraViewController: CameraViewController
    private var initialTouchPoint: CGPoint = .zero
    
    init(cameraViewController: CameraViewController) {
        self.cameraViewController = cameraViewController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add camera view controller as child
        addChild(cameraViewController)
        view.addSubview(cameraViewController.view)
        cameraViewController.view.frame = view.bounds
        cameraViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cameraViewController.didMove(toParent: self)
        
        // Add pan gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let touchPoint = gesture.location(in: view.window)
        
        switch gesture.state {
        case .began:
            initialTouchPoint = touchPoint
            
        case .changed:
            let yOffset = touchPoint.y - initialTouchPoint.y
            if yOffset > 0 { // Only allow downward swipe
                view.frame.origin.y = yOffset
                
                // Add some scaling effect
                let scale = 1 - (yOffset / 1000)
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
            
        case .ended, .cancelled:
            let yOffset = touchPoint.y - initialTouchPoint.y
            let velocity = gesture.velocity(in: view).y
            
            // Dismiss if pulled down far enough or with enough velocity
            if yOffset > 200 || velocity > 500 {
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.frame.origin.y = self.view.frame.height
                    self.view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                }) { _ in
                    self.dismiss(animated: false)
                }
            } else {
                // Reset position if not dismissed
                UIView.animate(withDuration: 0.3) {
                    self.view.frame.origin.y = 0
                    self.view.transform = .identity
                }
            }
            
        default:
            break
        }
    }
}

class ShowVideoCamera: NSObject {
    weak var presentingViewController: UIViewController?

    func showCamera() {
        // Create configuration
        let configuration = Configuration { builder in
            builder.configureCameraViewController { options in
                // Only allow video recording, no photos
                options.allowedRecordingModes = [.video]
                // Start with front camera first, but allow switching to back
                options.allowedCameraPositions = [.front, .back]
                // Only allow portrait orientation
                options.allowedRecordingOrientations = [.portrait]
                options.showCancelButton = true
            }
        }

        // Create the camera view controller
        let cameraViewController = CameraViewController(configuration: configuration)
        
        // Create wrapper controller with swipe-to-dismiss
        let wrapperController = SwipeDismissalController(cameraViewController: cameraViewController)
        wrapperController.modalPresentationStyle = .fullScreen

        // Called when the user finishes recording or picks a video from the camera roll
        cameraViewController.completionBlock = { [weak self] result in
            // `result.url` is the file URL of the recorded (or selected) video
            guard let url = result.url else { return }
            print("Received video at \(url.absoluteString)")
            
            // Use the wrapper controller to dismiss itself
            wrapperController.dismiss(animated: true)
        }

        // Called when the user taps the cancel button
        cameraViewController.cancelBlock = { [weak self] in
            print("Cancel button tapped")
            // Use the wrapper controller to dismiss itself
            wrapperController.dismiss(animated: true)
        }

        // Present the wrapper controller instead of camera directly
        presentingViewController?.present(wrapperController, animated: true)
    }
}