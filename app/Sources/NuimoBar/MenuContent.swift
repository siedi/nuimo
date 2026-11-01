import AppKit
import SwiftUI

/// Items of the menu bar menu.
struct MenuContent: View {
    let state: AppState
    @Bindable var log: DebugLog
    let configURL: URL
    let selectMode: (String?) -> Void

    var body: some View {
        Text(state.statusText)
        if let profile = state.profileText {
            Text(profile)
        }
        if let activity = state.lastActivityText {
            Text(activity)
        }
        if let error = state.configError {
            Text(String(localized: "⚠ Error in config.toml: \(error)"))
        }
        Divider()
        if !state.modeNames.isEmpty {
            Menu(String(localized: "Mode")) {
                ForEach(state.modeNames, id: \.self) { name in
                    Toggle(name, isOn: modeBinding(name))
                }
            }
        }
        Button(String(localized: "Edit mapping …")) {
            NSWorkspace.shared.open(configURL)
        }
        Toggle(String(localized: "Debug log"), isOn: $log.isEnabled)
        Button(String(localized: "Open log …")) {
            log.ensureFileExists()
            NSWorkspace.shared.open(log.fileURL)
        }
        Divider()
        Button(String(localized: "Quit")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// Checked while the mode is active; unchecking it switches the mode off.
    private func modeBinding(_ name: String) -> Binding<Bool> {
        Binding(get: { state.activeMode == name }, set: { selectMode($0 ? name : nil) })
    }
}
