import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let prefs: Preferences
    private var window: NSWindow?

    init(prefs: Preferences) {
        self.prefs = prefs
    }

    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(prefs: prefs))
            let window = NSWindow(contentViewController: controller)
            window.title = "TopDock Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @Bindable var prefs: Preferences

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityTrusted = AXIsProcessTrusted()

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        Form {
            Section("Appearance") {
                LabeledContent("Icon size") {
                    HStack {
                        Slider(value: $prefs.iconSize, in: 14...24, step: 1)
                        Text("\(Int(prefs.iconSize)) pt").monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                }
                LabeledContent("Icon spacing") {
                    HStack {
                        Slider(value: $prefs.iconSpacing, in: 0...8, step: 1)
                        Text("\(Int(prefs.iconSpacing)) pt").monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                }
                Toggle("Magnify icons on hover", isOn: $prefs.magnify)
                Slider(value: $prefs.magnification, in: 1.2...2.6) {
                    Text("Magnification")
                }
                .disabled(!prefs.magnify)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Haptic feedback on hover", isOn: $prefs.haptics)
                    Text("Taps the Force Touch trackpad when moving between icons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show notification badges", isOn: $prefs.showBadges)
                    Text("Shows the same red badges as the Dock. Requires Accessibility access.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Content") {
                Stepper("Maximum icons in the menu bar: \(prefs.maxSlots)", value: $prefs.maxSlots, in: 3...60)
                Text("TopDock follows your Dock: Finder and the apps kept in the Dock in the same order, then other running apps and the Dock's recent apps. Change the order or \"Show suggested and recent apps\" in the Dock itself. Scroll over the icons to page through apps that don't fit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Clicking the active app hides it", isOn: $prefs.clickActiveHides)
                Toggle("Hide when the menu bar is hidden (fullscreen, auto-hide)", isOn: $prefs.hideWhenMenuBarHidden)
                Toggle("Show on all displays", isOn: $prefs.allDisplays)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show TopDock icon in the menu bar", isOn: $prefs.showMenuBarIcon)
                    Text("When the icon is hidden, open TopDock again (from Finder, Spotlight or Launchpad) to bring up this window.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            NSLog("TopDock: launch at login failed: \(error.localizedDescription)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Available space") {
                LabeledContent("Accessibility access") {
                    if accessibilityTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Grant Access…") {
                            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                        }
                    }
                }
                Text("With Accessibility access, TopDock measures the current app's menus and uses all the free space next to them. Without it, TopDock uses the width below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Width without access") {
                    HStack {
                        Slider(value: $prefs.fallbackWidth, in: 200...1000, step: 20)
                        Text("\(Int(prefs.fallbackWidth)) pt").monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                }
                .disabled(accessibilityTrusted)
            }

            Section {
                LabeledContent("TopDock \(version)") {
                    HStack {
                        Button("About TopDock") { AboutPanel.show() }
                        Button("Quit TopDock") { NSApp.terminate(nil) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 640)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            accessibilityTrusted = AXIsProcessTrusted()
        }
    }
}
