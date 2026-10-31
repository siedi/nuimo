import AppKit
import ApplicationServices

/// Creates the app's parts on launch and connects them.
@MainActor
final class AppModel: NSObject, NSApplicationDelegate {
    let state = AppState()
    let log = DebugLog()
    private(set) lazy var configStore = ConfigStore(log: log)

    private let scheduler = MainScheduler()
    private lazy var device = NuimoDevice(scheduler: scheduler, log: log)
    private lazy var controller = Controller(
        outputs: SystemOutputs(device: device, log: log),
        config: { [configStore] in configStore.current() },
        frontmostApp: { FrontmostApp.current() },
        scheduler: scheduler,
        log: log
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("NuimoBar started")
        requestAccessibilityIfNeeded()

        configStore.onErrorChange = { [weak self] error in
            self?.state.configError = error
        }
        configStore.installDefaultIfMissing(from: Bundle.main.url(forResource: "default-config", withExtension: "toml"))
        configStore.reloadIfChanged()

        controller.onActivity = { [weak self] activity in
            self?.state.lastActivity = activity
        }
        device.onStatusChange = { [weak self] status in
            self?.statusChanged(status)
        }
        device.onBatteryLevel = { [weak self] level in
            self?.state.batteryLevel = level
        }
        device.onInput = { [weak self] input in
            self?.controller.handle(input)
        }
        device.onReady = { [weak self] in
            self?.device.show(.smiley, seconds: 1)
        }
        device.start()
    }

    private func statusChanged(_ status: ConnectionStatus) {
        state.connection = status
        if !status.isConnected {
            state.batteryLevel = nil
            controller.reset()
        }
    }

    /// Without the Accessibility permission, keys, media keys and scrolling do not reach other apps.
    /// macOS shows its prompt only if the permission is missing.
    private func requestAccessibilityIfNeeded() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        log("Accessibility permission: \(trusted)")
    }
}
