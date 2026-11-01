import AppKit
import ApplicationServices

/// Creates the app's parts on launch and connects them.
@MainActor
final class AppModel: NSObject, NSApplicationDelegate {
    static let activeModeKey = "activeMode"
    /// How often the config file is checked while no events arrive, so the menu shows errors and modes.
    static let configCheckInterval: Duration = .seconds(2)

    let state = AppState()
    let log = DebugLog()
    private(set) lazy var configStore = ConfigStore(log: log)

    private let defaults = UserDefaults.standard
    private let scheduler = MainScheduler()
    private lazy var device = NuimoDevice(scheduler: scheduler, log: log)
    private lazy var midi = MIDIOut(log: log)
    private lazy var controller = Controller(
        outputs: SystemOutputs(device: device, midi: midi, log: log),
        config: { [configStore] in configStore.current() },
        frontmostApp: { FrontmostApp.current() },
        scheduler: scheduler,
        log: log
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("NuimoBar started")
        requestAccessibilityIfNeeded()
        midi.start()
        setUpConfig()
        setUpController()
        setUpDevice()
        scheduleConfigCheck()
    }

    /// Switches the mode from the menu.
    func selectMode(_ name: String?) {
        controller.switchMode(to: name)
    }

    private func setUpConfig() {
        configStore.onErrorChange = { [weak self] error in
            self?.state.configError = error
        }
        configStore.onReload = { [weak self] config in
            self?.state.modeNames = config.modeNames
        }
        configStore.installDefaultIfMissing(from: Bundle.main.url(forResource: "default-config", withExtension: "toml"))
        configStore.reloadIfChanged()
    }

    private func setUpController() {
        controller.onActivity = { [weak self] activity in
            self?.state.lastActivity = activity
        }
        controller.onModeChange = { [weak self] mode in
            self?.modeChanged(mode)
        }
        // Restore the mode from the last run, if the file still has it.
        if let mode = defaults.string(forKey: Self.activeModeKey), configStore.config.modes[mode] != nil {
            controller.activeMode = mode
            state.activeMode = mode
            log("Restored mode \(mode)")
        } else {
            modeChanged(nil)
        }
    }

    private func setUpDevice() {
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

    private func modeChanged(_ mode: String?) {
        state.activeMode = mode
        defaults.set(mode, forKey: Self.activeModeKey)
    }

    private func statusChanged(_ status: ConnectionStatus) {
        state.connection = status
        if !status.isConnected {
            state.batteryLevel = nil
            controller.reset()
        }
    }

    private func scheduleConfigCheck() {
        scheduler.schedule(after: Self.configCheckInterval) { [weak self] in
            guard let self else { return }
            self.configStore.reloadIfChanged()
            // A mode removed from the file is off; quietly, without an image on the matrix.
            if let mode = self.controller.activeMode, self.configStore.config.modes[mode] == nil {
                self.log("Mode \(mode) no longer exists, switching it off")
                self.controller.activeMode = nil
                self.modeChanged(nil)
            }
            self.scheduleConfigCheck()
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
