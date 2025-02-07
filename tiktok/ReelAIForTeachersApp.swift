import SwiftUI
import Firebase

@main
struct ReelAIForTeachersApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
#if DEBUG
        // Use the debug provider in development.
#else
        // In production, you might want to use the default provider or another appropriate provider.
        // For example, if you target devices that support DeviceCheck, you can simply let Firebase use it.
#endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
