import SwiftUI

struct TeacherLogo: View {
    var body: some View {
        ZStack {
            // Graduation cap icon as the base of the logo.
            Image(systemName: "graduationcap.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
            
            // Overlay a letter "T" for Teacher
            Text("T")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .offset(y: 4) // adjust vertical alignment if needed
        }
        .frame(width: 70, height: 70)
        // Optionally, clip to a circular shape for a badge-style logo.
        .background(Color.white.opacity(0.2))
        .clipShape(Circle())
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

#if DEBUG
struct TeacherLogo_Previews: PreviewProvider {
    static var previews: some View {
        // App Icon sizes needed for iOS:
        // 1024x1024 - App Store
        // 180x180   - iPhone 6 Plus & iPhone 6s Plus (3x)
        // 120x120   - iPhone & iPod touch (2x and 3x)
        // 167x167   - iPad Pro
        // 152x152   - iPad & iPad mini
        // 76x76     - iPad (1x)
        
        Group {
            TeacherLogo()
                .frame(width: 1024, height: 1024) // App Store
                .previewDisplayName("1024pt")
            
            TeacherLogo()
                .frame(width: 180, height: 180) // iPhone 6 Plus
                .previewDisplayName("180pt")
            
            TeacherLogo()
                .frame(width: 167, height: 167) // iPad Pro
                .previewDisplayName("167pt")
            
            TeacherLogo()
                .frame(width: 152, height: 152) // iPad
                .previewDisplayName("152pt")
            
            TeacherLogo()
                .frame(width: 120, height: 120) // iPhone
                .previewDisplayName("120pt")
            
        TeacherLogo()
                .frame(width: 76, height: 76) // iPad 1x
                .previewDisplayName("76pt")
        }
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
