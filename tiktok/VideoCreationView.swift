import SwiftUI
import AVFoundation
import PhotosUI
import AVKit
import FirebaseStorage
import UIKit

class CameraManager: NSObject, ObservableObject {
    @Published var error: Error?
    @Published var session = AVCaptureSession()
    @Published var isRecording = false
    private var camera: AVCaptureDevice?
    private var cameraInput: AVCaptureDeviceInput?
    private let cameraQueue = DispatchQueue(label: "CameraQueue")
    private var videoOutput: AVCaptureMovieFileOutput?
    @Published var recordedVideoURL: URL?
    
    override init() {
        super.init()
    }
    
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
            
            // Add video output with proper settings
            let videoOutput = AVCaptureMovieFileOutput()
            
            // Set video orientation and dimensions
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                
                // Configure video connection for portrait orientation
                if let connection = videoOutput.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
                
                // Set video dimensions and quality
                session.sessionPreset = .hd1920x1080 // 1080p
                
                self.videoOutput = videoOutput
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
    
    func toggleRecording() {
        if isRecording {
            videoOutput?.stopRecording()
        } else {
            guard let videoOutput = videoOutput else { return }
            
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            
            // Configure recording settings
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1080, // Portrait mode: width is smaller
                AVVideoHeightKey: 1920 // Height is larger for 9:16 aspect ratio
            ]
            
            // Set video connection properties
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            
            videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        }
        isRecording.toggle()
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.error = error
            }
            return
        }
        
        DispatchQueue.main.async {
            self.recordedVideoURL = outputFileURL
            self.isRecording = false
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Optional: Handle recording start
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
        
        // Ensure preview is in portrait orientation
        if view.previewLayer.connection?.isVideoOrientationSupported ?? false {
            view.previewLayer.connection?.videoOrientation = .portrait
        }
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

struct VideoCreationView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingFilePicker = false
    @State private var videoDescription = ""
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var showTrimmer = false
    @State private var isProcessing = false
    @State private var processingError: Error?
    
    private let videoCompressor = VideoCompressor()
    
    @State private var uploadProgress: Double = 0
    
    private func processAndUploadVideo(url: URL) async {
        isProcessing = true
        
        do {
            let compressedURL = try await videoCompressor.compressVideo(inputURL: url)
            
            let storageRef = Storage.storage().reference()
            let videoName = "\(UUID().uuidString).mp4"
            let videoRef = storageRef.child("videos/\(videoName)")
            
            let uploadTask = videoRef.putFile(from: compressedURL, metadata: nil)
            
            uploadTask.observe(.progress) { snapshot in
                let percentComplete = Double(snapshot.progress!.completedUnitCount)
                    / Double(snapshot.progress!.totalUnitCount)
                DispatchQueue.main.async {
                    uploadProgress = percentComplete
                }
            }
            
            let _ = try await uploadTask.snapshot
            
            try? FileManager.default.removeItem(at: compressedURL)
            try? FileManager.default.removeItem(at: url)
            
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                isProcessing = false
                processingError = error
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(session: cameraManager.session)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .task {
                        cameraManager.checkPermissions()
                    }
                
                VStack(spacing: 0) {
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
                    
                    VStack(spacing: 20) {
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
                            
                            Button(action: { 
                                cameraManager.toggleRecording()
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 75, height: 75)
                                    
                                    Circle()
                                        .fill(cameraManager.isRecording ? Color.red : Color.white)
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
                
                if isProcessing {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Processing video... \(Int(uploadProgress * 100))%")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
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
        .sheet(isPresented: $showTrimmer) {
            if let videoURL = cameraManager.recordedVideoURL {
                VideoTrimmerView(url: videoURL)
            }
        }
        .onChange(of: cameraManager.recordedVideoURL) { newURL in
            if newURL != nil {
                showTrimmer = true
            }
        }
        .alert("Processing Error", isPresented: .constant(processingError != nil)) {
            Button("OK") {
                processingError = nil
            }
        } message: {
            Text(processingError?.localizedDescription ?? "")
        }
    }
}

#Preview {
    VideoCreationView()
}
