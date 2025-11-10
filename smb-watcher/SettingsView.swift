import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("username") private var username = ""
    @AppStorage("checkInterval") private var checkInterval = 5
    @State private var password = ""
    
    var body: some View {
        Form {
            Section(header: Text("Server Connection (for auto-remount)")) {
                TextField("Server URL (e.g., smb://server.com)", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                Button("Save Credentials") {
                    savePassword()
                }
            }
            
            Section(header: Text("Monitoring")) {
                Stepper("Check every \(checkInterval) minutes", value: $checkInterval, in: 1...60)
            }
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 450, height: 350)
        .onAppear {
            loadPassword()
        }
    }
    
    func savePassword() {
        guard !serverURL.isEmpty else {
            print("Server URL is required")
            return
        }
        
        let success = KeychainHelper.shared.save(password: password, for: serverURL)
        if success {
            print("✓ Password saved to Keychain")
        } else {
            print("✗ Failed to save password")
        }
    }
    
    func loadPassword() {
        if !serverURL.isEmpty {
            if let savedPassword = KeychainHelper.shared.retrieve(for: serverURL) {
                password = savedPassword
            }
        }
    }
}
