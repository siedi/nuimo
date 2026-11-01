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
            String(localized: "Searching for Nuimo … (press once)")
        case .connected:
            if let batteryLevel {
                String(localized: "Connected · Battery \(batteryLevel) %")
            } else {
                String(localized: "Connected")
            }
        case .bluetoothOff:
            String(localized: "Bluetooth is off")
        case .unauthorized:
            String(localized: "Bluetooth not allowed")
        case .unsupported:
            String(localized: "Bluetooth unavailable")
        }
    }
}
