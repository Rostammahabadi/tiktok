import SwiftUI

struct VideoCreationView: View {
    @State private var isRecording = false
    @State private var videoTitle = ""
    @State private var videoDescription = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Camera preview placeholder
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.secondaryColor)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            Image(systemName: "video")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(Theme.textColor)
                                .frame(width: 60, height: 60)
                        )
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            isRecording.toggle()
                        }) {
                            Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .foregroundColor(isRecording ? .red : Theme.accentColor)
                        }
                        
                        Button(action: {
                            // Implement upload logic
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(Theme.accentColor)
                        }
                    }
                    
                    VStack(spacing: 10) {
                        TextField("Video Title", text: $videoTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Video Description", text: $videoDescription)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        // Implement publish logic
                    }) {
                        Text("Publish")
                            .font(Theme.headlineFont)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Create Video")
        }
    }
}

