import SwiftUI
import UIKit

struct GraduationBirdAnimation: View {
    @Binding var isShowing: Bool
    let onComplete: () -> Void
    
    // MARK: - State Properties
    @State private var birdOffset: CGSize = CGSize(width: -UIScreen.main.bounds.width, height: 0)
    @State private var birdScale: CGFloat = 0.5
    @State private var rotationAngle: Double = -15
    @State private var opacity: Double = 1
    @State private var showStars: Bool = false
    @State private var starOpacity: Double = 0
    @State private var appleOpacity: Double = 0
    @State private var showApple: Bool = false
    @State private var teacherMessage: String = ""
    @State private var messageOpacity: Double = 0
    @State private var isAnimating: Bool = false
    @State private var canDismiss: Bool = false
    
    // MARK: - Constants
    private let teacherMessages = [
        "Great job teaching today! 🎓",
        "You're making a difference! 📚",
        "Your students are lucky to have you! ⭐️",
        "Another successful lesson! 🌟",
        "Teaching hearts and minds! 💝"
    ]
    
    // MARK: - Body
    var body: some View {
        ZStack {
            if isShowing {
                // Tappable background for dismissal
                Color.black
                    .opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onTapGesture {
                        if canDismiss {
                            withAnimation {
                                cleanupAndDismiss()
                            }
                        }
                    }
                
                // Main content container
                VStack {
                    // Stars animation
                    ZStack {
                        ForEach(0..<12, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.yellow)
                                .offset(x: CGFloat.random(in: -150...150),
                                      y: CGFloat.random(in: -150...150))
                                .opacity(starOpacity)
                                .rotationEffect(.degrees(Double(index) * 30))
                                .scaleEffect(showStars ? 1.2 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.1),
                                    value: showStars
                                )
                        }
                        
                        // The "bird with cap" as a single composited view
                        ZStack {
                            // Bird
                            Image(systemName: "bird.fill")
                                .font(.system(size: 40))
                                .offset(y: isAnimating ? -5 : 5)
                                .animation(
                                    Animation.easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                            
                            // Graduation cap
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 20))
                                .offset(x: -2, y: -20)
                        }
                        .foregroundColor(.white)
                        .offset(birdOffset)
                        .scaleEffect(birdScale)
                        .rotationEffect(.degrees(rotationAngle))
                        
                        // Apple for teacher
                        Image(systemName: "apple.logo")
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                            .offset(x: 40, y: -30)
                            .opacity(appleOpacity)
                            .rotationEffect(.degrees(showApple ? 360 : 0))
                            .animation(
                                Animation.easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: false),
                                value: showApple
                            )
                    }
                    
                    // Congratulatory message
                    Text(teacherMessage)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.blue.opacity(0.6))
                                .shadow(radius: 10)
                        )
                        .opacity(messageOpacity)
                        .scaleEffect(messageOpacity)
                    
                    if canDismiss {
                        Text("Tap anywhere to continue")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(size: 14))
                            .padding(.top, 20)
                            .transition(.opacity)
                    }
                }
                .onAppear {
                    startAnimation()
                }
            }
        }
        .animation(.easeInOut, value: isShowing)
    }
    
    // MARK: - Animation Methods
    private func startAnimation() {
        // Select random teacher message
        teacherMessage = teacherMessages.randomElement() ?? teacherMessages[0]
        
        // Initial bird animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            birdOffset = .zero
            birdScale = 1.2
            rotationAngle = 0
            isAnimating = true
        }
        
        // Sequence the animations
        withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
            showStars = true
            starOpacity = 1
            showApple = true
            appleOpacity = 1
        }
        
        withAnimation(.spring(response: 0.6).delay(0.5)) {
            messageOpacity = 1
        }
        
        // Enable dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                canDismiss = true
            }
        }
    }
    
    private func cleanupAndDismiss() {
        withAnimation(.easeInOut(duration: 0.5)) {
            opacity = 0
            starOpacity = 0
            appleOpacity = 0
            messageOpacity = 0
            birdOffset = CGSize(width: UIScreen.main.bounds.width, height: -UIScreen.main.bounds.height)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isShowing = false
            onComplete()
        }
    }
}