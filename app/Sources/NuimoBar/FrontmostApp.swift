import AppKit

/// The app in front, which selects the app profile.
struct FrontmostApp: Equatable, Sendable {
    /// Name as shown in the Dock.
    var name: String
    var bundleID: String?

    @MainActor
    static func current() -> FrontmostApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FrontmostApp(name: app.localizedName ?? app.bundleIdentifier ?? "", bundleID: app.bundleIdentifier)
    }
}
