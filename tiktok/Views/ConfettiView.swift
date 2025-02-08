import SwiftUI

struct ConfettiView: View {
    @Binding var isActive: Bool
    let duration: Double
    
    private let colors: [Color] = [
        Theme.primaryColor,
        Theme.accentColor,
        Color(red: 0.98, green: 0.4, blue: 0.4),
        Color(red: 0.98, green: 0.8, blue: 0.3),
        Color.white
    ]
    
    private let numberOfPieces = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<numberOfPieces, id: \.self) { index in
                    ConfettiPiece(color: colors[index % colors.count],
                                size: geometry.size,
                                isActive: isActive,
                                duration: duration)
                }
            }
            .opacity(isActive ? 1 : 0)
        }
    }
}

private struct ConfettiPiece: View {
    let color: Color
    let size: CGSize
    let isActive: Bool
    let duration: Double
    
    @State private var position: CGPoint = .zero
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.01
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .position(x: position.x, y: position.y)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                if isActive {
                    animate()
                }
            }
            .onChange(of: isActive) { newValue in
                if newValue {
                    reset()
                    animate()
                }
            }
    }
    
    private func reset() {
        position = CGPoint(x: size.width / 2, y: size.height / 2)
        rotation = 0
        scale = 0.01
    }
    
    private func animate() {
        let randomX = Double.random(in: 0...size.width)
        let randomY = Double.random(in: -50...0)
        
        withAnimation(.easeOut(duration: duration)) {
            position = CGPoint(x: randomX, y: randomY)
            rotation = Double.random(in: 0...360) * 5
            scale = 1.0
        }
    }
}
