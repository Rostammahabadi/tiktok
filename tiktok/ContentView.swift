import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    
    var body: some View {
        if isLoggedIn {
            TabView {
                VideoFeedView()
                    .tabItem {
                        Label("Feed", systemImage: "play.rectangle.fill")
                    }
                
                VideoCreationView()
                    .tabItem {
                        Label("Create", systemImage: "video.badge.plus")
                    }
                
                TeacherProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
            }
            .accentColor(Theme.accentColor)
        } else {
            WelcomeView(isLoggedIn: $isLoggedIn)
        }
    }
}

