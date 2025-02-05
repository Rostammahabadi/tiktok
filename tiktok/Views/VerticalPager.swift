import SwiftUI

struct VerticalPager<Content: View>: View {
    let pageCount: Int
    @Binding var currentIndex: Int
    let content: Content
    
    private let dragThreshold: CGFloat = 20
    private let velocityThreshold: CGFloat = 300
    @GestureState private var translation: CGFloat = 0
    
    init(pageCount: Int, currentIndex: Binding<Int>, @ViewBuilder content: () -> Content) {
        self.pageCount = pageCount
        self._currentIndex = currentIndex
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                content
                    .frame(width: geometry.size.width)
                    .offset(y: -CGFloat(currentIndex) * geometry.size.height)
                    .offset(y: translation)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($translation) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        if abs(value.translation.height) > dragThreshold || 
                           abs(value.predictedEndTranslation.height) > velocityThreshold {
                            let direction = (value.translation.height > 0) ? -1 : 1
                            let newIndex = currentIndex + direction
                            if newIndex >= 0 && newIndex < pageCount {
                                currentIndex = newIndex
                            }
                        }
                    }
            )
        }
    }
}
