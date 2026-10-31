import AppKit
import SwiftUI

/// Items of the menu bar menu.
struct MenuContent: View {
    let state: AppState
    @Bindable var log: DebugLog

    var body: some View {
        Text(state.statusText)
        if let gesture = state.lastGesture {
            Text(String(localized: "Letzte Geste: \(gesture)"))
        }
        Divider()
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
