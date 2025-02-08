import SwiftUI

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    var style: CustomTextFieldStyle = .light
    
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(style.placeholderColor)
                    .padding(.horizontal, 16)
            }
            
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .textFieldStyle(.plain)
            .foregroundColor(style.textColor)
            .tint(style.tintColor)
            .padding(.horizontal, 16)
        }
        .frame(height: 50)
        .background(style.backgroundColor)
        .cornerRadius(style.cornerRadius)
    }
}

enum CustomTextFieldStyle {
    case light
    case dark
    case darkTransparent
    
    var backgroundColor: Color {
        switch self {
        case .light:
            return Color(.systemBackground)
        case .dark:
            return Color.white.opacity(0.2)
        case .darkTransparent:
            return Color.black.opacity(0.3)
        }
    }
    
    var textColor: Color {
        switch self {
        case .light:
            return Color(.label)
        case .dark, .darkTransparent:
            return .white
        }
    }
    
    var placeholderColor: Color {
        switch self {
        case .light:
            return Color(.placeholderText)
        case .dark:
            return Color.white.opacity(0.7)
        case .darkTransparent:
            return Color.white.opacity(0.6)
        }
    }
    
    var tintColor: Color {
        switch self {
        case .light:
            return Theme.accentColor
        case .dark, .darkTransparent:
            return .white
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .light:
            return 12
        case .dark:
            return 25
        case .darkTransparent:
            return 12
        }
    }
}
