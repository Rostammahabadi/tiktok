import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    
    init() {
        // Set consistent tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        if isLoggedIn {
            TabView {
                VideoFeedView()
                    .tabItem {
                        Label("Feed", systemImage: "play.rectangle.fill")
                    }
                
                CreateView()
                    .tabItem {
                        Label("Create", systemImage: "video.badge.plus")
                    }
                
                TeacherProfileView(isLoggedIn: $isLoggedIn)
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
            }
            .accentColor(Color.white)
        } else {
            WelcomeView(isLoggedIn: $isLoggedIn)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
