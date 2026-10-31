import AppKit
import SwiftUI

/// Entry point: a menu bar extra without a Dock icon (`LSUIElement` in Info.plist).
@main
struct NuimoBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text(String(localized: "NuimoBar \(Self.version)"))
            Divider()
            Button(String(localized: "Beenden")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: "dial.low")
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }
}
