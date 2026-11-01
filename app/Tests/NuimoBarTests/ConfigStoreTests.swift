import Foundation
import Testing

@testable import NuimoBar

@MainActor
struct ConfigStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "NuimoBarTests-\(UUID().uuidString)")
    var fileURL: URL { directory.appending(path: "NuimoBar/config.toml") }

    /// Writes the file and sets a distinct modification date, so a change is always noticed.
    func write(_ text: String, at seconds: TimeInterval) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: seconds)], ofItemAtPath: fileURL.path)
    }

    @Test func loadsAndReloadsOnChange() throws {
        try write("[default]\npress = \"keys:a\"", at: 1000)
        let store = ConfigStore(fileURL: fileURL)
        #expect(store.current().standard["press"] == "keys:a")
        try write("[default]\npress = \"keys:b\"", at: 2000)
        #expect(store.current().standard["press"] == "keys:b")
        #expect(store.error == nil)
    }

    @Test func unchangedDateDoesNotReload() throws {
        try write("[default]\npress = \"keys:a\"", at: 1000)
        let store = ConfigStore(fileURL: fileURL)
        _ = store.current()
        try write("[default]\npress = \"keys:b\"", at: 1000)
        #expect(store.current().standard["press"] == "keys:a")
    }

    @Test func syntaxErrorKeepsThePreviousMapping() throws {
        try write("[default]\npress = \"keys:a\"", at: 1000)
        let store = ConfigStore(fileURL: fileURL)
        var errors: [String?] = []
        store.onErrorChange = { errors.append($0) }
        _ = store.current()
        try write("[default\npress = ", at: 2000)
        #expect(store.current().standard["press"] == "keys:a")
        #expect(store.error?.hasPrefix("Line 1") == true)
        try write("[default]\npress = \"keys:c\"", at: 3000)
        #expect(store.current().standard["press"] == "keys:c")
        #expect(store.error == nil)
        #expect(errors.count == 2)
    }

    @Test func missingFileIsReported() {
        let store = ConfigStore(fileURL: fileURL)
        #expect(store.current() == Config())
        #expect(store.error == "File not found")
    }

    @Test func installsTheDefaultOnlyOnce() throws {
        let source = directory.appending(path: "default.toml")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "[default]\npress = \"media:mute\"".write(to: source, atomically: true, encoding: .utf8)
        let store = ConfigStore(fileURL: fileURL)
        store.installDefaultIfMissing(from: source)
        #expect(store.current().standard["press"] == "media:mute")

        try write("[default]\npress = \"keys:a\"", at: 1000)
        store.installDefaultIfMissing(from: source)
        #expect(store.current().standard["press"] == "keys:a")
    }
}
