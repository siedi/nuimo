import AppKit
import SwiftUI

/// Items of the menu bar menu.
struct MenuContent: View {
    let state: AppState
    @Bindable var log: DebugLog
    let configURL: URL

    var body: some View {
        Text(state.statusText)
        if let profile = state.profileText {
            Text(profile)
        }
        if let activity = state.lastActivityText {
            Text(activity)
        }
        if let error = state.configError {
            Text(String(localized: "⚠ Fehler in config.toml: \(error)"))
        }
        Divider()
        Button(String(localized: "Belegung bearbeiten …")) {
            NSWorkspace.shared.open(configURL)
        }
        Toggle(String(localized: "Debug-Log"), isOn: $log.isEnabled)
        Button(String(localized: "Log öffnen …")) {
            log.ensureFileExists()
            NSWorkspace.shared.open(log.fileURL)
        }
        Divider()
        Button(String(localized: "Beenden")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
