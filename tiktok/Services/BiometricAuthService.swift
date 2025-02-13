import LocalAuthentication
import SwiftUI

class BiometricAuthService: ObservableObject {
    @Published var isAuthenticated = false
    private let context = LAContext()
    private var error: NSError?
    
    enum BiometricType {
        case none
        case faceID
        case touchID
    }
    
    var biometricType: BiometricType {
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
    
    func authenticateUser() async -> Bool {
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ Biometric authentication not available: \(error?.localizedDescription ?? "")")
            return false
        }
        
        do {
            // Attempt authentication
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Sign in to MathTok"
            )
            
            await MainActor.run {
                self.isAuthenticated = success
            }
            return success
        } catch {
            print("❌ Authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func signOut() {
        isAuthenticated = false
    }
}
