import SwiftUI
import UserNotifications
import AppKit

struct ContentView: View {
    @State private var status = "Not connected"
    @State private var fileCount = 0
    @State private var previousFileCount: Int? = nil
    @State private var timer: Timer?
    @State private var selectedFolderPath = "No folder selected"
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("username") private var username = ""
    @AppStorage("checkInterval") private var checkInterval = 5 // minutes
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Server Monitor")
                .font(.headline)
            
            Divider()
            
            HStack {
                Image(systemName: "externaldrive.fill")
                VStack(alignment: .leading) {
                    Text("Status: \(status)")
                    Text("Files: \(fileCount)")
                        .foregroundColor(.secondary)
                }
            }
            
            Text(selectedFolderPath)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Divider()
            
            Button("Select Folder") {
                selectFolder()
            }
            
            Button("Check Now") {
                checkServer()
            }
            .disabled(selectedFolderPath == "No folder selected")
            
            Button("Settings") {
                openSettings()
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            
            //Button("Test Notification") {
            //    ServerManager.shared.sendNotification(
            //        title: "Test Notification",
            //        body: "If you see this, notifications are working!"
            //    )
            //}
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            requestNotificationPermission()
            loadSavedFolder()
            loadPreviousFileCount()
            if selectedFolderPath != "No folder selected" {
                startPeriodicChecks()
            }
        }
        .onDisappear {
            stopPeriodicChecks()
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the network folder to monitor"
        panel.prompt = "Select"
        
        panel.treatsFilePackagesAsDirectories = false
        panel.canChooseDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    
                    UserDefaults.standard.set(bookmarkData, forKey: "folderBookmark")
                    UserDefaults.standard.set(url.path, forKey: "folderPath")
                    
                    self.selectedFolderPath = url.path
                    print("[ContentView] Folder selected and bookmark saved: \(url.path)")
                    
                    // Reset previous count when selecting new folder
                    self.previousFileCount = nil
                    UserDefaults.standard.removeObject(forKey: "previousFileCount")
                    
                    startPeriodicChecks()
                    
                } catch {
                    print("[ContentView] Failed to create bookmark: \(error)")
                    self.status = "Failed to save folder"
                }
            }
        }
    }
    
    func loadSavedFolder() {
        if let path = UserDefaults.standard.string(forKey: "folderPath") {
            selectedFolderPath = path
            print("[ContentView] Loaded saved folder path: \(path)")
        }
    }
    
    func loadPreviousFileCount() {
        if UserDefaults.standard.object(forKey: "previousFileCount") != nil {
            previousFileCount = UserDefaults.standard.integer(forKey: "previousFileCount")
            print("[ContentView] Loaded previous file count: \(previousFileCount ?? 0)")
        }
    }
    
    func startPeriodicChecks() {
        stopPeriodicChecks()
        print("[ContentView] Starting periodic checks every \(checkInterval) minutes")
        checkServer()
        
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(checkInterval * 60), repeats: true) { _ in
            print("[ContentView] ⏰ Timer fired - running automatic check")
            self.checkServer()
        }
    }
    
    func stopPeriodicChecks() {
        timer?.invalidate()
        timer = nil
    }
    
    func checkServer() {
        guard selectedFolderPath != "No folder selected" else {
            status = "Please select a folder"
            return
        }
        
        print("[ContentView] Starting check (manual or timer)")
        status = "Checking..."
        
        ServerManager.shared.checkServerFilesWithBookmark { result in
            switch result {
            case .success(let count):
                self.fileCount = count
                self.status = "Connected ✓"
                print("[ContentView] ✓ Check successful: \(count) files")
                
                // Check if file count increased
                if let previous = self.previousFileCount {
                    if count > previous {
                        let increase = count - previous
                        print("[ContentView] 📈 File count increased by \(increase) - SENDING NOTIFICATION")
                        ServerManager.shared.sendNotification(
                            title: "New Files Detected! 📁",
                            body: "File count increased from \(previous) to \(count) (+\(increase) files)",
                            folderPath: self.selectedFolderPath  // Add this parameter
                        )
                    } else if count < previous {
                        print("[ContentView] 📉 File count decreased by \(previous - count) (from \(previous) to \(count))")
                    } else {
                        print("[ContentView] File count unchanged: \(count)")
                    }
                } else {
                    print("[ContentView] First check - baseline set to \(count) files")
                }
                
                // Save current count as previous for next check
                self.previousFileCount = count
                UserDefaults.standard.set(count, forKey: "previousFileCount")
                
            case .failure(let error):
                self.status = "Error"
                print("[ContentView] ✗ Check failed: \(error.localizedDescription)")
                ServerManager.shared.sendNotification(
                    title: "Server Error",
                    body: error.localizedDescription,
                    folderPath: nil  // No folder path for errors
                )
            }
        }
    }
    
    func requestNotificationPermission() {
        // Set the delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[ContentView] Notification permission granted")
            } else if let error = error {
                print("[ContentView] Notification permission denied: \(error)")
            }
        }
    }
    
    func openSettings() {
        SettingsWindowManager.shared.open()
    }
}
