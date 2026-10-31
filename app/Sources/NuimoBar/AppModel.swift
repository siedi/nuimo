import AppKit

/// Creates the app's parts on launch and connects them.
@MainActor
final class AppModel: NSObject, NSApplicationDelegate {
    let state = AppState()
    let log = DebugLog()

    private let scheduler = MainScheduler()
    private lazy var device = NuimoDevice(scheduler: scheduler, log: log)
    private lazy var gestures = ButtonGestures(scheduler: scheduler) { [weak self] gesture in
        self?.handle(gesture)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("NuimoBar started")
        device.onStatusChange = { [weak self] status in
            self?.statusChanged(status)
        }
        device.onBatteryLevel = { [weak self] level in
            self?.state.batteryLevel = level
        }
        device.onInput = { [weak self] input in
            self?.handle(input)
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
            gestures.reset()
        }
    }

    private func handle(_ input: NuimoProtocol.Input) {
        switch input {
        case .button(let pressed):
            if pressed {
                gestures.press()
            } else {
                gestures.release()
            }
        case .rotation:
            gestures.rotated()
        case .gesture(let gesture):
            handle(gesture)
        }
    }

    // Until the controller exists, gestures are only shown in the menu and on the matrix, like nuimo.py does.
    private func handle(_ gesture: Gesture) {
        log("Gesture: \(gesture.rawValue)")
        state.lastGesture = gesture.rawValue
        device.show(gesture.feedbackImage, seconds: 0.8)
    }
}
