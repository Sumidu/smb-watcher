//
//  smb_watcherApp.swift
//  smb-watcher
//
//  Created by André Calero Valdez on 10.11.25.
//

import SwiftUI

@main
struct smb_watcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
       var popover = NSPopover()
       var settingsWindow: NSWindow?
    
    func openSettings() {
            if settingsWindow == nil {
                let settingsView = SettingsView()
                let hostingController = NSHostingController(rootView: settingsView)
                let window = NSWindow(contentViewController: hostingController)
                window.title = "Settings"
                window.styleMask = [.titled, .closable]
                window.center()
                window.delegate = self
                
                self.settingsWindow = window
            }
            
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow?.makeKeyAndOrderFront(nil)
        }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "Server Monitor")
            button.action = #selector(togglePopover)
        }
        
        // Set up popover content
        popover.contentViewController = NSHostingController(rootView: ContentView())
        popover.behavior = .transient
    }
    
    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem?.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == settingsWindow {
            settingsWindow = nil
        }
    }
}
