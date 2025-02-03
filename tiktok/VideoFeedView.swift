import SwiftUI

struct VideoFeedView: View {
    let videos = [
        Video(title: "Introduction to Algebra", description: "Learn the basics of algebraic equations", author: "Jane Smith"),
        Video(title: "The Solar System", description: "Explore our cosmic neighborhood", author: "John Doe"),
        Video(title: "World War II", description: "A brief overview of WWII", author: "Alice Johnson")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(videos) { video in
                        VideoCard(video: video)
                    }
                }
                .padding()
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Video Feed")
        }
    }
}

struct Video: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let author: String
}

struct VideoCard: View {
    let video: Video
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Video thumbnail placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.secondaryColor)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Image(systemName: "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(Theme.textColor)
                )
            
            Text(video.title)
                .font(Theme.headlineFont)
                .foregroundColor(Theme.textColor)
            
            Text(video.description)
                .font(Theme.bodyFont)
                .foregroundColor(Theme.textColor.opacity(0.8))
            
            HStack {
                Text(video.author)
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textColor.opacity(0.6))
                
                Spacer()
                
                Button(action: {
                    isLiked.toggle()
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : Theme.textColor)
                }
                .animation(.spring(), value: isLiked)
                
                Button(action: {
                    // Implement comment action
                }) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(Theme.textColor)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

