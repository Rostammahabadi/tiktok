import SwiftUI

struct GraduationBirdAnimation: View {
    @Binding var isShowing: Bool
    let onComplete: () -> Void
    
    @State private var birdOffset: CGSize = CGSize(width: -UIScreen.main.bounds.width, height: 0)
    @State private var birdScale: CGFloat = 0.5
    @State private var rotationAngle: Double = -15
    @State private var opacity: Double = 1
    
    var body: some View {
        ZStack {
            if isShowing {
                // Dimmed background
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                // The "bird with cap" as a single composited view
                ZStack {
                    // Bird
                    Image(systemName: "bird.fill")
                        .font(.system(size: 40))
                    
                    // Graduation cap, sized + positioned
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 20))
                        .offset(x: -2, y: -20)
                        // Optionally rotate the cap a bit:
                        //.rotationEffect(.degrees(-10))
                }
                .foregroundColor(.white)
                // Animate this entire ZStack
                .offset(birdOffset)
                .scaleEffect(birdScale)
                .rotationEffect(.degrees(rotationAngle))
                .opacity(opacity)
                .onAppear {
                    // 1) Animate from left into center
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        birdOffset = .zero
                        birdScale = 1.2
                        rotationAngle = 0
                    }
                    
                    // 2) Then fly away
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeInOut(duration: 0.7)) {
                            birdOffset = CGSize(width: UIScreen.main.bounds.width,
                                                height: -UIScreen.main.bounds.height)
                            birdScale = 0.5
                            rotationAngle = 15
                            opacity = 0
                        }
                        
                        // 3) Cleanup after flight
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            isShowing = false
                            onComplete()
                        }
                    }
                }
            }
        }
        .animation(.easeInOut, value: isShowing)
    }
}