import Foundation
import Swift
import SwiftUI

enum GenerationStep: Identifiable {
    case scriptGeneration
    case scriptApproval
    case videoRendering
    case videoDownload
    case complete
    
    var id: Int {
        switch self {
        case .scriptGeneration: return 1
        case .scriptApproval: return 2
        case .videoRendering: return 3
        case .videoDownload: return 4
        case .complete: return 5
        }
    }
    
    var title: String {
        switch self {
        case .scriptGeneration: return "Generating Script"
        case .scriptApproval: return "Review Script"
        case .videoRendering: return "Rendering Video"
        case .videoDownload: return "Downloading Video"
        case .complete: return "Complete"
        }
    }
    
    var icon: String {
        switch self {
        case .scriptGeneration: return "wand.and.stars"
        case .scriptApproval: return "text.viewfinder"
        case .videoRendering: return "film.stack"
        case .videoDownload: return "arrow.down.circle"
        case .complete: return "checkmark.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .scriptGeneration: return "Creating your educational script with AI..."
        case .scriptApproval: return "Review and approve your script"
        case .videoRendering: return "Transforming your script into an animated video..."
        case .videoDownload: return "Getting your video ready..."
        case .complete: return "Your video is ready!"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .scriptGeneration:
            return [Color(red: 0.98, green: 0.4, blue: 0.4), Color(red: 0.98, green: 0.8, blue: 0.3)]
        case .scriptApproval:
            return [Color(red: 0.98, green: 0.8, blue: 0.3), Color(red: 0.4, green: 0.8, blue: 0.98)]
        case .videoRendering:
            return [Color(red: 0.4, green: 0.8, blue: 0.98), Color(red: 0.5, green: 0.4, blue: 0.98)]
        case .videoDownload:
            return [Color(red: 0.5, green: 0.4, blue: 0.98), Color(red: 0.98, green: 0.4, blue: 0.8)]
        case .complete:
            return [Color(red: 0.3, green: 0.8, blue: 0.4), Color(red: 0.4, green: 0.9, blue: 0.5)]
        }
    }
}

struct GenerationProgress {
    var currentStep: GenerationStep = .scriptGeneration
    var scriptText: String = ""
    var manimCode: String = ""
    var videoURL: String = ""
    var message: String = ""
    var error: Error?
    
    var isComplete: Bool {
        currentStep == .complete
    }
    
    var canProceed: Bool {
        switch currentStep {
        case .scriptApproval:
            return !scriptText.isEmpty
        case .complete:
            return !manimCode.isEmpty
        default:
            return true
        }
    }
}
