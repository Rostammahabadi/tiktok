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

struct TeacherLogo_Previews: PreviewProvider {
    static var previews: some View {
        TeacherLogo()
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.gray.opacity(0.2))
    }
}
