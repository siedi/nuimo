/// State of the Bluetooth connection to the Nuimo as shown in the menu.
enum ConnectionStatus: Equatable, Sendable {
    /// Bluetooth is on and a connection request is pending, or the app scans for the Nuimo.
    case searching
    case connected
    case bluetoothOff
    case unauthorized
    case unsupported

    var isConnected: Bool { self == .connected }

    /// The status line at the top of the menu.
    func menuText(batteryLevel: Int?) -> String {
        switch self {
        case .searching:
            String(localized: "Suche Nuimo … (einmal drücken)")
        case .connected:
            if let batteryLevel {
                String(localized: "Verbunden · Akku \(batteryLevel) %")
            } else {
                String(localized: "Verbunden")
            }
        case .bluetoothOff:
            String(localized: "Bluetooth ist aus")
        case .unauthorized:
            String(localized: "Bluetooth nicht erlaubt")
        case .unsupported:
            String(localized: "Bluetooth nicht verfügbar")
        }
    }
}
