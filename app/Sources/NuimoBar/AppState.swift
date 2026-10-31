import Observation

/// Observable state the menu shows.
@Observable
@MainActor
final class AppState {
    var connection: ConnectionStatus = .searching
    var batteryLevel: Int?
    var lastActivity: Controller.Activity?
    /// Error in `config.toml`, already in German.
    var configError: String?

    var statusText: String {
        connection.menuText(batteryLevel: batteryLevel)
    }

    /// "Profil: TradingView", "Profil: Standard" or "Modus: Resolume", once an event was handled.
    var profileText: String? {
        switch lastActivity?.profile {
        case .mode(let name): String(localized: "Modus: \(name)")
        case .app(let name): String(localized: "Profil: \(name)")
        case .standard: String(localized: "Profil: Standard")
        case nil: nil
        }
    }

    /// "Letzte Geste: press → keys:opt+return", or a note that the event is not mapped.
    var lastActivityText: String? {
        guard let activity = lastActivity else { return nil }
        if let action = activity.action {
            return String(localized: "Letzte Geste: \(activity.event) → \(action)")
        }
        return String(localized: "Letzte Geste: \(activity.event) (nicht belegt)")
    }
}
