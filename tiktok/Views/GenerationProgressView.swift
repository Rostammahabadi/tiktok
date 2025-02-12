import SwiftUI

struct GenerationProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var progress: GenerationProgress
    @ObservedObject var viewModel: AIBuilderViewModel
    var regenerateScript: () async -> Void
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // Current Step Animation
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: progress.currentStep.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        )
                        .shadow(radius: 10)
                    
                    Image(systemName: progress.currentStep.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(scale)
                        .onAppear {
                            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                            withAnimation(Animation.easeInOut(duration: 1).repeatForever()) {
                                scale = 1.2
                            }
                        }
                }
                .padding(.top, 20)
                
                // Step Title and Description
                VStack(spacing: 8) {
                    Text(progress.currentStep.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if progress.currentStep == .scriptGeneration {
                        Text(progress.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text(progress.currentStep.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                if progress.currentStep == .scriptApproval {
                    // Script Review Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Review Generated Script")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(progress.scriptText)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxHeight: 300)
                        .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                Task {
                                    await regenerateScript()
                                }
                            }) {
                                Label("New Script", systemImage: "arrow.clockwise")
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                withAnimation {
                                    progress.currentStep = .videoRendering
                                }
                                Task {
                                    do {
                                        try await viewModel.continueWithVideo()
                                    } catch {
                                        print("Error continuing with video: \(error)")
                                        withAnimation {
                                            progress.currentStep = .scriptApproval
                                        }
                                    }
                                }
                            }) {
                                Label("Continue", systemImage: "arrow.right")
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(!progress.canProceed)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    // Progress Steps
                    VStack(spacing: 0) {
                        ForEach([
                            GenerationStep.scriptGeneration,
                            .scriptApproval,
                            .videoRendering,
                            .videoDownload,
                            .complete
                        ], id: \.id) { step in
                            HStack(spacing: 15) {
                                // Step number circle with icon
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: step.gradientColors),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 40, height: 40)
                                        .opacity(step.id <= progress.currentStep.id ? 1 : 0.3)
                                    
                                    Image(systemName: step.icon)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title)
                                        .font(.headline)
                                        .foregroundColor(step.id <= progress.currentStep.id ? .primary : .secondary)
                                    
                                    if step.id == progress.currentStep.id {
                                        Text(step.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if step.id < progress.currentStep.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(step.id == progress.currentStep.id ? Color.gray.opacity(0.1) : Color.clear)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.vertical)
                }
                
                Spacer()
            }
            .navigationTitle("Creating Your Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if progress.currentStep == .scriptApproval {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview Provider
struct GenerationProgressView_Previews: PreviewProvider {
    static var previews: some View {
        GenerationProgressView(
            progress: .constant(GenerationProgress(
                currentStep: .scriptApproval,
                scriptText: "This is a sample script that would be generated by the AI."
            )),
            viewModel: AIBuilderViewModel(),
            regenerateScript: { }
        )
    }
}
