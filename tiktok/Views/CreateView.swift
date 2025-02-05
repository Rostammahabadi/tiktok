import SwiftUI
import UIKit

struct CreateView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                Text("Create Content")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Spacer()
                
                // Camera Option
                Button(action: {
                    // Open camera
                }) {
                    VStack(spacing: 15) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                        Text("Record Video")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.blue)
                    .cornerRadius(15)
                }
                .padding(.horizontal)
                
                // Studio Option
                Button(action: {
                    let editor = ShowVideoEditor()
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        editor.presentingViewController = rootViewController
                        editor.showVideoEditor()
                    }
                }) {
                    VStack(spacing: 15) {
                        Image(systemName: "video.badge.plus.fill")
                            .font(.system(size: 40))
                        Text("Open Studio")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.purple)
                    .cornerRadius(15)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
        }
    }
}

#Preview {
    CreateView()
}
