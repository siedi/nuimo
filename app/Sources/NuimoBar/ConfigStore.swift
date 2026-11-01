import Foundation

/// Keeps the mapping from `config.toml` and reloads it when the file's modification date changes.
/// After a syntax error the previous mapping stays active and ``error`` describes the problem.
@MainActor
final class ConfigStore {
    static let defaultFileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/NuimoBar/config.toml")

    let fileURL: URL
    private(set) var config = Config()
    /// Text for the menu, or `nil` if the file loaded fine.
    private(set) var error: String? {
        didSet {
            if error != oldValue {
                onErrorChange?(error)
            }
        }
    }
    var onErrorChange: ((String?) -> Void)?
    /// Called after the file was loaded successfully.
    var onReload: ((Config) -> Void)?

    private let log: DebugLog?
    private var loadedModificationDate: Date?
    private var hasCheckedFile = false

    init(fileURL: URL = defaultFileURL, log: DebugLog? = nil) {
        self.fileURL = fileURL
        self.log = log
    }

    /// Copies the bundled default mapping if the file does not exist yet.
    func installDefaultIfMissing(from defaultURL: URL?) {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: fileURL.path), let defaultURL else { return }
        do {
            try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try manager.copyItem(at: defaultURL, to: fileURL)
            log?("Installed default config at \(fileURL.path)")
        } catch {
            log?("Installing default config failed: \(error)")
        }
    }

    /// The current mapping; reloads the file first if it changed.
    func current() -> Config {
        reloadIfChanged()
        return config
    }

    func reloadIfChanged() {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modificationDate = attributes?[.modificationDate] as? Date
        guard !hasCheckedFile || modificationDate != loadedModificationDate else { return }
        hasCheckedFile = true
        loadedModificationDate = modificationDate

        guard modificationDate != nil, let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            log?("Config not readable at \(fileURL.path), keeping the previous mapping")
            error = String(localized: "File not found")
            return
        }
        do throws(Config.SyntaxError) {
            config = try Config(parsing: text)
            error = nil
            log?("Config loaded")
            for warning in config.warnings {
                log?("Config warning: \(warning)")
            }
            onReload?(config)
        } catch {
            log?("Config syntax error, keeping the previous mapping: \(error.message)")
            self.error = error.localizedDescription
        }
    }
}
