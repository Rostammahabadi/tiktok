import SwiftUI
import FirebaseAuth

struct TeacherProfileView: View {
    @State private var selectedTab = 0
    @Binding var isLoggedIn: Bool
    
    let videos = [
        Video(title: "Introduction to Algebra", description: "Learn the basics of algebraic equations", author: "Jane Smith"),
        Video(title: "The Solar System", description: "Explore our cosmic neighborhood", author: "Jane Smith"),
        Video(title: "World War II", description: "A brief overview of WWII", author: "Jane Smith")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    VStack {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(Theme.accentColor)
                        
                        Text("Jane Smith")
                            .font(Theme.titleFont)
                            .foregroundColor(Theme.accentColor)
                        
                        Text("Math Teacher | 10 years experience")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textColor.opacity(0.8))
                    }
                    .padding()
                    
                    // Tab view for videos and about
                    Picker("", selection: $selectedTab) {
                        Text("Videos").tag(0)
                        Text("About").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if selectedTab == 0 {
                        // Videos grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            ForEach(videos) { video in
                                VideoThumbnail(video: video)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // About section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("About Me")
                                .font(Theme.headlineFont)
                                .foregroundColor(Theme.textColor)
                            
                            Text("I'm passionate about making math accessible and fun for all students. With 10 years of teaching experience, I specialize in creating engaging video content to supplement classroom learning.")
                                .font(Theme.bodyFont)
                                .foregroundColor(Theme.textColor.opacity(0.8))
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: logout) {
                        Text("Logout")
                            .foregroundColor(Theme.accentColor)
                    }
                }
            }
        }
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

struct VideoThumbnail: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.secondaryColor)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Image(systemName: "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(Theme.textColor)
                )
            
            Text(video.title)
                .font(Theme.captionFont)
                .foregroundColor(Theme.textColor)
                .lineLimit(2)
        }
    }
}

