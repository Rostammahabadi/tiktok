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

// Updated TeacherWelcomeView with modern gradient background
struct TeacherWelcomeView: View {
    @Binding var isLoggedIn: Bool
    @State private var showLogin = false
    @State private var showSignup = false

    var body: some View {
        ZStack {
            // Modern gradient background for welcome screen
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemGray6), Color(.systemGray)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()
                
                // Add TeacherLogo on top of the TeacherTok title
                TeacherLogo()
                    .frame(width: 70, height: 70) // Adjust the frame as needed

                Text("TeacherTok")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 0, y: 2)
                
                Text("A social platform for educators to share engaging content")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: { showLogin = true }) {
                        Text("Log in with email")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    
                    Button(action: { showSignup = true }) {
                        Text("Sign up")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    
                    Button(action: {
                        // Action for Apple login (to be integrated)
                    }) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.title2)
                            Text("Continue with Apple")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 30)
                
                Text("By continuing, you agree to our Terms of Service and acknowledge that you have read our Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView(isLoggedIn: $isLoggedIn)
        }
        .sheet(isPresented: $showSignup) {
            SignupView(isLoggedIn: $isLoggedIn)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
