import Foundation
import Observation

/// Optional log file for raw data, gestures, actions and errors. Off by default; the setting is kept in
/// `UserDefaults`.
@Observable
@MainActor
final class DebugLog {
    static let defaultFileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/NuimoBar/debug.log")
    static let enabledKey = "debugLog"

    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                self("Debug log enabled")
            } else {
                closeFile()
            }
        }
    }

    let fileURL: URL

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var handle: FileHandle?
    @ObservationIgnored private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    init(fileURL: URL = defaultFileURL, defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.defaults = defaults
        self.now = now
        isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    /// Appends a line with a timestamp if the log is enabled. The message is only built when needed.
    func callAsFunction(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let line = "\(formatter.string(from: now())) \(message())\n"
        do {
            try openFileIfNeeded().write(contentsOf: Data(line.utf8))
        } catch {
            closeFile()
        }
    }

    /// Creates the file, so it can be opened even before anything was logged.
    func ensureFileExists() {
        _ = try? openFileIfNeeded()
    }

    private func openFileIfNeeded() throws -> FileHandle {
        if let handle {
            return handle
        }
        let manager = FileManager.default
        try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !manager.fileExists(atPath: fileURL.path) {
            manager.createFile(atPath: fileURL.path, contents: nil)
        }
        let newHandle = try FileHandle(forWritingTo: fileURL)
        try newHandle.seekToEnd()
        handle = newHandle
        return newHandle
    }

    private func closeFile() {
        try? handle?.close()
        handle = nil
    }
}
