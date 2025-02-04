import SwiftUI
import AVFoundation
import PhotosUI
import AVKit

class CameraManager: ObservableObject {
    @Published var error: Error?
    @Published var session = AVCaptureSession()
    private var camera: AVCaptureDevice?
    private var cameraInput: AVCaptureDeviceInput?
    private let cameraQueue = DispatchQueue(label: "CameraQueue")
    
    func checkPermissions() {
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                await MainActor.run {
                    setupCamera()
                }
            case .notDetermined:
                if await AVCaptureDevice.requestAccess(for: .video) {
                    await MainActor.run {
                        setupCamera()
                    }
                }
            default:
                await MainActor.run {
                    self.error = CameraError.deniedAccess
                }
            }
        }
    }
    
    func setupCamera() {
        session.beginConfiguration()
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: .back) else {
            self.error = CameraError.unavailable
            session.commitConfiguration()
            return
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
                self.cameraInput = cameraInput
            }
            
            session.commitConfiguration()
            
            // Start running on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        } catch {
            self.error = error
        }
    }
    
    func switchCamera() {
        guard let currentInput = cameraInput else { return }
        let currentPosition = currentInput.device.position
        
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: newPosition) else { return }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            
            session.beginConfiguration()
            session.removeInput(currentInput)
            
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                cameraInput = newInput
            }
            
            session.commitConfiguration()
        } catch {
            self.error = error
        }
    }
}

enum CameraError: Error {
    case deniedAccess
    case unavailable
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        @available(iOS, deprecated: 17.0, message: "Using deprecated videoOrientation for compatibility")
        func setOrientation() {
            view.previewLayer.connection?.videoOrientation = .portrait
        }
        setOrientation()
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

struct VideoCreationView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isRecording = false
    @State private var showingFilePicker = false
    @State private var videoDescription = ""
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var showTrimmer = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(session: cameraManager.session)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .task {
                        // Start camera when view appears
                        cameraManager.checkPermissions()
                    }
                
                // Overlay controls
                VStack(spacing: 0) {
                    // Top controls
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 20) {
                            Button(action: {}) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "timer")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack(spacing: 20) {
                        // Effects scroll
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(["Speed", "Beauty", "Filters", "Timer", "Flash", "More"], id: \.self) { effect in
                                    Text(effect)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 10)
                        
                        // Recording controls
                        HStack(spacing: 30) {
                            Button(action: { showingFilePicker = true }) {
                                Image(systemName: "photo")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                            .photosPicker(
                                isPresented: $showingFilePicker,
                                selection: $selectedItem,
                                matching: .videos
                            )
                            .onChange(of: selectedItem) { newItem in
                                if let newItem {
                                    Task {
                                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                                            let tempURL = FileManager.default.temporaryDirectory
                                                .appendingPathComponent(UUID().uuidString)
                                                .appendingPathExtension("mov")
                                            try? data.write(to: tempURL)
                                            videoURL = tempURL
                                            showTrimmer = true
                                        }
                                    }
                                }
                            }
                            
                            // Record button
                            Button(action: { isRecording.toggle() }) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 75, height: 75)
                                    
                                    Circle()
                                        .fill(isRecording ? Color.red : Color.white)
                                        .frame(width: 65, height: 65)
                                }
                            }
                            
                            Button(action: { cameraManager.switchCamera() }) {
                                Image(systemName: "camera.rotate")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                    .background(Color.black.opacity(0.3))
                }
            }
        }
        .alert("Camera Error", isPresented: .constant(cameraManager.error != nil)) {
            Button("OK") {
                cameraManager.error = nil
            }
        } message: {
            Text(cameraManager.error?.localizedDescription ?? "")
        }
        .sheet(isPresented: $showTrimmer, onDismiss: {
            // Reset selection when trimmer is dismissed
            selectedItem = nil
            videoURL = nil
        }) {
            if let videoURL {
                VideoTrimmerView(url: videoURL)
            }
        }
    }
}

#Preview {
    VideoCreationView()
}
