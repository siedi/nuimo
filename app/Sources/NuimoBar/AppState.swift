import Observation

/// Observable state the menu shows.
@Observable
@MainActor
final class AppState {
    var connection: ConnectionStatus = .searching
    var batteryLevel: Int?
    /// Name of the last gesture, as in `config.toml`.
    var lastGesture: String?

    var statusText: String {
        connection.menuText(batteryLevel: batteryLevel)
    }
}
