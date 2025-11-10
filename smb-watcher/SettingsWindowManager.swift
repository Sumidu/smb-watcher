import SwiftUI
import AppKit

class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    
    private var window: NSWindow?
    
    private init() {}  // Add private init for singleton
    
    func open() {
        if window == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.title = "Settings"
            newWindow.styleMask = [.titled, .closable]
            newWindow.center()
            
            // Handle window closing
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: newWindow,
                queue: .main
            ) { [weak self] _ in
                self?.window = nil
            }
            
            self.window = newWindow
        }
        
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
