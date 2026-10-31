import Foundation
import Testing

@testable import NuimoBar

@MainActor
struct DebugLogTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "NuimoBarTests-\(UUID().uuidString)")
    let suiteName = "NuimoBarTests-\(UUID().uuidString)"
    var fileURL: URL { directory.appending(path: "logs/debug.log") }
    var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }

    func makeLog() -> DebugLog {
        DebugLog(fileURL: fileURL, defaults: defaults, now: { Date(timeIntervalSince1970: 0) })
    }

    func contents() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    @Test func disabledByDefaultAndWritesNothing() {
        let log = makeLog()
        #expect(!log.isEnabled)
        log("hidden")
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func enabledLogAppendsTimestampedLines() {
        let log = makeLog()
        log.isEnabled = true
        log("first")
        log("second")
        let lines = contents().split(separator: "\n")
        #expect(lines.count == 3)
        #expect(lines[1].hasSuffix(" first"))
        #expect(lines[2].hasSuffix(" second"))
        #expect(lines[1].hasPrefix("1970-01-01 "))
    }

    @Test func messageIsNotBuiltWhileDisabled() {
        let log = makeLog()
        let counter = MessageCounter()
        log(counter.message())
        #expect(counter.count == 0)
    }

    @Test func settingIsRemembered() {
        makeLog().isEnabled = true
        #expect(makeLog().isEnabled)
    }

    @Test func disablingStopsWritingAndReEnablingAppends() {
        let log = makeLog()
        log.isEnabled = true
        log("one")
        log.isEnabled = false
        log("hidden")
        log.isEnabled = true
        log("two")
        let text = contents()
        #expect(text.contains(" one\n"))
        #expect(!text.contains("hidden"))
        #expect(text.contains(" two\n"))
    }

    @Test func ensureFileExistsCreatesAnEmptyFile() {
        makeLog().ensureFileExists()
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(contents().isEmpty)
    }
}

@MainActor
final class MessageCounter {
    private(set) var count = 0

    func message() -> String {
        count += 1
        return "message \(count)"
    }
}
