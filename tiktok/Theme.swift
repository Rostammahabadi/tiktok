import SwiftUI

struct Theme {
    static let primaryColor = Color(red: 0/255, green: 122/255, blue: 255/255)
        
    // A dark gray that can be used for backgrounds, shadows, etc.
    static let secondaryColor = Color(red: 34/255, green: 34/255, blue: 34/255)
    
    // Accent color: this is based on your existing AccentColor.colorset (magenta/pink),
    // but here we define it directly so that it’s available even if the asset is missing.
    static let accentColor = Color(red: 1.0, green: 0.478, blue: 1.0)
    
    // For a modern, sleek look, use a very dark background.
    static let backgroundColor = Color(red: 24/255, green: 24/255, blue: 24/255)
    
    // For text that appears on dark backgrounds, white works best.
    static let textColor = Color.white
//    static let backgroundColor = Color("TeacherBackground") // Updated background color
    
    
    static let titleFont = Font.system(size: 28, weight: .bold)
    static let headlineFont = Font.system(size: 20, weight: .semibold)
    static let bodyFont = Font.system(size: 16, weight: .regular)
    static let captionFont = Font.system(size: 14, weight: .regular)
}
