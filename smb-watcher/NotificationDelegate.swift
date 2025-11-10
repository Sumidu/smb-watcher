import Foundation
import UserNotifications
import AppKit

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print("[NotificationDelegate] Notification clicked!")
        
        // Load bookmark and resolve it
        guard let bookmarkData = UserDefaults.standard.data(forKey: "folderBookmark") else {
            print("[NotificationDelegate] No bookmark found")
            completionHandler()
            return
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            print("[NotificationDelegate] Opening folder: \(url.path)")
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("[NotificationDelegate] Failed to access security-scoped resource")
                completionHandler()
                return
            }
            
            // Open the folder in Finder
            NSWorkspace.shared.open(url)
            
            // Stop accessing after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                url.stopAccessingSecurityScopedResource()
            }
            
        } catch {
            print("[NotificationDelegate] Failed to resolve bookmark: \(error)")
        }
        
        completionHandler()
    }
    
    // This allows notifications to show even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
