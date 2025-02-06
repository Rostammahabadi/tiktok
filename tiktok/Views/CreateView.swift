import SwiftUI
import AVKit
import UIKit

struct CreateView: View {
    // MARK: - Properties
    @State private var showCamera = false
    @State private var isAnimating = false
    @State private var streakCount = 0
    @State private var showAchievement = false
    @State private var achievementTitle = ""
    @State private var showHelp = false
    
    // Matching gradient colors from WelcomeView
    let gradientColors: [Color] = [
        Color(red: 0.98, green: 0.4, blue: 0.4),   // Playful red
        Color(red: 0.98, green: 0.8, blue: 0.3),   // Warm yellow
        Color(red: 0.4, green: 0.8, blue: 0.98)    // Sky blue
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: gradientColors),
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header with help button
                HStack {
                    Text("Create")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        showHelp = true
                    }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                Spacer()
                
                // Camera Option
                Button(action: {
                    showCamera = true
                    increaseStreak()
                }) {
                    VStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        Text("Record Video")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .scaleEffect(isAnimating ? 1.02 : 1)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                             value: isAnimating)
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
                    increaseStreak()
                }) {
                    VStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        Text("Edit Video")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .scaleEffect(isAnimating ? 1.02 : 1)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.2),
                             value: isAnimating)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            
            // Achievement popup
            if showAchievement {
                AchievementPopup(title: achievementTitle)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            isAnimating = true
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(streakCount: $streakCount)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }
    
    private func increaseStreak() {
        streakCount += 1
        if streakCount % 5 == 0 {
            showAchievement(title: " \(streakCount) Creation Streak!")
        }
    }
    
    private func showAchievement(title: String) {
        achievementTitle = title
        withAnimation {
            showAchievement = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showAchievement = false
            }
        }
    }
}

struct AchievementPopup: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(15)
            .padding()
    }
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var streakCount: Int
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }
            
            // Camera implementation will go here
            Text("Camera View")
                .foregroundColor(.white)
        }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    let helpItems: [(icon: String, title: String, description: String)] = [
        ("camera.fill", "Record Video", "Create a new video using your camera. Perfect for capturing moments in real-time."),
        ("wand.and.stars", "Edit Video", "Use our video editor to enhance your videos with effects, filters, and more."),
        ("hand.tap", "Quick Tips", "• Tap and hold to record\n• Double tap to switch cameras\n• Swipe up for more options"),
        ("sparkles", "Effects", "Access various effects and filters while recording or editing your videos."),
        ("arrow.up.circle", "Share", "Once you're done, share your creation with the world!")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.9).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        ForEach(helpItems, id: \.title) { item in
                            HelpItemView(icon: item.icon, title: item.title, description: item.description)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("How to Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct HelpItemView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 32)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.leading, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    CreateView()
}
