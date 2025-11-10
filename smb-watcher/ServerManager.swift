import Foundation
import UserNotifications

class ServerManager {
    static let shared = ServerManager()
    
    private init() {}
    
   func checkServerFilesWithBookmark(completion: @escaping (Result<Int, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Load bookmark
                guard let bookmarkData = UserDefaults.standard.data(forKey: "folderBookmark") else {
                    throw NSError(domain: "ServerManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No folder selected"])
                }
                
                // Also get the stored path for remounting
                guard let folderPath = UserDefaults.standard.string(forKey: "folderPath") else {
                    throw NSError(domain: "ServerManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Folder path not found"])
                }
                
                // Extract volume name from path (e.g., /Volumes/sekretariat)
                let volumePath = self.getVolumePath(from: folderPath)
                
                print("[ServerManager] Checking if volume exists: \(volumePath)")
                
                // Check if server is mounted
                if !FileManager.default.fileExists(atPath: volumePath) {
                    print("[ServerManager] Volume not mounted, attempting to remount...")
                    
                    // Get credentials
                    guard let serverURL = UserDefaults.standard.string(forKey: "serverURL"),
                          !serverURL.isEmpty,
                          let username = UserDefaults.standard.string(forKey: "username"),
                          !username.isEmpty,
                          let password = KeychainHelper.shared.retrieve(for: serverURL) else {
                        throw NSError(domain: "ServerManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Server disconnected. Please configure credentials in Settings."])
                    }
                    
                    // Mount the server
                    try self.mountServer(serverURL: serverURL, username: username, password: password)
                    
                    // Wait for mount
                    Thread.sleep(forTimeInterval: 3.0)
                    
                    // Verify it mounted
                    guard FileManager.default.fileExists(atPath: volumePath) else {
                        throw NSError(domain: "ServerManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to remount server. Check credentials and network."])
                    }
                    
                    print("[ServerManager] ✓ Server remounted successfully")
                } else {
                    print("[ServerManager] ✓ Volume already mounted")
                }
                
                // Now resolve bookmark
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    print("[ServerManager] Warning: Bookmark is stale")
                }
                
                print("[ServerManager] Resolved URL: \(url.path)")
                
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "ServerManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot access folder. Permissions denied."])
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                // Count files
                let fileCount = try self.countFiles(at: url)
                
                print("[ServerManager] ✓ Successfully counted \(fileCount) files")
                
                DispatchQueue.main.async {
                    completion(.success(fileCount))
                }
                
            } catch {
                print("[ServerManager] Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func getVolumePath(from path: String) -> String {
        // Extract volume name from path like /Volumes/sekretariat/...
        let pathComponents = path.components(separatedBy: "/")
        if pathComponents.count > 2 && pathComponents[1] == "Volumes" {
            return "/Volumes/" + pathComponents[2]
        }
        return path
    }

    private func mountServer(serverURL: String, username: String, password: String) throws {
        // URL encode credentials
        guard let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed),
              let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) else {
            throw NSError(domain: "ServerManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to encode credentials"])
        }
        
        // Build SMB URL with credentials
        var cleanURL = serverURL.replacingOccurrences(of: "smb://", with: "")
        if cleanURL.hasSuffix("/") {
            cleanURL.removeLast()
        }
        
        let smbURL = "smb://\(encodedUsername):\(encodedPassword)@\(cleanURL)"
        
        print("[ServerManager] Mounting: smb://\(encodedUsername):***@\(cleanURL)")
        
        // Use open command to mount
        let openCommand = "open '\(smbURL)'"
        let result = self.executeShellCommand(openCommand)
        
        if !result.success {
            print("[ServerManager] Mount command output: \(result.output)")
            throw NSError(domain: "ServerManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Mount command failed: \(result.output)"])
        }
    }

    private func executeShellCommand(_ command: String) -> (output: String, success: Bool) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return (output, task.terminationStatus == 0)
        } catch {
            return (error.localizedDescription, false)
        }
    }
    
    private func countFiles(at url: URL) throws -> Int {
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        // Filter to only count files (not directories)
        let files = contents.filter { fileURL in
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDirectory = resourceValues.isDirectory else {
                return false
            }
            return !isDirectory  // Only count if it's NOT a directory
        }
        
        return files.count
    }
    
    func sendNotification(title: String, body: String, folderPath: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Add folder path to userInfo so we can open it when clicked
        if let folderPath = folderPath {
            content.userInfo = ["folderPath": folderPath]
        }
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
