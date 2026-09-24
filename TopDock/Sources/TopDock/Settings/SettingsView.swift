import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let prefs: Preferences
    private let store: AppStore
    private var window: NSWindow?

    init(prefs: Preferences, store: AppStore) {
        self.prefs = prefs
        self.store = store
    }

    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(prefs: prefs, store: store))
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
    let store: AppStore

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var pinCount: Int

    init(prefs: Preferences, store: AppStore) {
        self.prefs = prefs
        self.store = store
        _pinCount = State(initialValue: store.pinnedPaths.count)
    }

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
                Toggle("Magnify icons on hover", isOn: $prefs.magnify)
                Slider(value: $prefs.magnification, in: 1.2...2.6) {
                    Text("Magnification")
                }
                .disabled(!prefs.magnify)
            }

            Section("Content") {
                Picker("Order running apps by", selection: $prefs.sortMode) {
                    ForEach(SortMode.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Show pinned apps first", isOn: $prefs.showPinned)
                Toggle("Show recently used apps that aren't running", isOn: $prefs.showRecents)
                Stepper("Recent apps: \(prefs.recentsLimit)", value: $prefs.recentsLimit, in: 1...12)
                    .disabled(!prefs.showRecents)
                Stepper("Maximum icons in the menu bar: \(prefs.maxSlots)", value: $prefs.maxSlots, in: 3...40)
                LabeledContent("Pinned apps: \(pinCount)") {
                    HStack {
                        Button("Import from Dock") {
                            store.importDockPins()
                            pinCount = store.pinnedPaths.count
                        }
                        Button("Clear") {
                            store.clearPins()
                            pinCount = store.pinnedPaths.count
                        }
                        .disabled(pinCount == 0)
                    }
                }
                Text("Drag an app from Finder onto TopDock to pin it, or drag pinned icons to reorder them. Scroll over the icons to page through apps that don't fit.")
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
