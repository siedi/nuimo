import Observation

/// Observable state the menu shows.
@Observable
@MainActor
final class AppState {
    var connection: ConnectionStatus = .searching
    var batteryLevel: Int?
    var lastActivity: Controller.Activity?
    /// Error in `config.toml`, ready for the menu.
    var configError: String?
    var activeMode: String?
    /// Modes from `config.toml`, sorted.
    var modeNames: [String] = []

    var statusText: String {
        connection.menuText(batteryLevel: batteryLevel)
    }

    /// "Mode: Resolume" while a mode is on, otherwise "Profile: TradingView" or "Profile: Default" once an
    /// event was handled.
    var profileText: String? {
        if let activeMode {
            return String(localized: "Mode: \(activeMode)")
        }
        switch lastActivity?.profile {
        case .mode, .standard: return String(localized: "Profile: Default")
        case .app(let name): return String(localized: "Profile: \(name)")
        case nil: return nil
        }
    }

    /// "Last gesture: press → keys:opt+return", or a note that the event is not mapped.
    var lastActivityText: String? {
        guard let activity = lastActivity else { return nil }
        if let action = activity.action {
            return String(localized: "Last gesture: \(activity.event) → \(action)")
        }
        return String(localized: "Last gesture: \(activity.event) (not mapped)")
    }
}
