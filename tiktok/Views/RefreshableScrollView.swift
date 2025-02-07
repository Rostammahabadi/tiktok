import SwiftUI

struct RefreshableScrollView<Content: View>: View {
    let onRefresh: (@escaping () -> Void) -> Void
    let content: Content
    
    init(onRefresh: @escaping (@escaping () -> Void) -> Void,
         @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        List {
            content
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .refreshable {
            await withCheckedContinuation { continuation in
                onRefresh {
                    continuation.resume()
                }
            }
        }
    }
}
