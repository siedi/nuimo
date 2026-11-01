import SwiftUI

/// Entry point: a menu bar extra without a Dock icon (`LSUIElement` in Info.plist).
@main
struct NuimoBarApp: App {
    @NSApplicationDelegateAdaptor private var model: AppModel

    var body: some Scene {
        MenuBarExtra {
            MenuContent(
                state: model.state,
                log: model.log,
                configURL: model.configStore.fileURL,
                selectMode: { model.selectMode($0) }
            )
        } label: {
            MenuBarIcon(state: model.state)
        }
    }
}

/// Symbol in the menu bar; filled while the Nuimo is connected.
private struct MenuBarIcon: View {
    let state: AppState

    var body: some View {
        Image(systemName: state.connection.isConnected ? "dial.low.fill" : "dial.low")
    }
}
