import Foundation
import TOMLKit

/// The parsed mapping from `config.toml`: settings, the standard profile, app profiles and modes.
struct Config: Equatable, Sendable {
    /// A TOML syntax error, with a position for the menu.
    struct SyntaxError: Error, Equatable {
        var line: Int
        var column: Int
        var message: String

        /// Text for the menu.
        var localizedDescription: String {
            String(localized: "Line \(line), column \(column): \(message)")
        }
    }

    var settings = Settings()
    var standard = Profile(kind: .standard)
    /// App profiles by app name or bundle ID, as written in the file.
    var apps: [String: [String: String]] = [:]
    var modes: [String: [String: String]] = [:]
    /// Ignored entries, for the debug log.
    var warnings: [String] = []

    init() {}

    init(parsing text: String) throws(SyntaxError) {
        let table: TOMLTable
        do {
            table = try TOMLTable(string: text)
        } catch let error as TOMLParseError {
            throw SyntaxError(
                line: error.source.begin.line, column: error.source.begin.column, message: error.description)
        } catch {
            throw SyntaxError(line: 0, column: 0, message: "\(error)")
        }

        if let section = table["settings"]?.table {
            settings = parseSettings(section)
        }
        if let section = table["default"]?.table {
            standard.entries = parseProfile(section, name: "default")
        }
        apps = parseProfiles(table["apps"]?.table, section: "apps")
        modes = parseProfiles(table["modes"]?.table, section: "modes")
    }

    /// Names of all modes, sorted for the menu.
    var modeNames: [String] {
        modes.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Profiles to search for an event, in order: active mode, profile of the app in front, standard.
    func profiles(for app: FrontmostApp?, mode: String?) -> [Profile] {
        var chain: [Profile] = []
        if let mode, let entries = modes[mode] {
            chain.append(Profile(kind: .mode(mode), entries: entries))
        }
        if let app, let entries = apps[app.name] ?? app.bundleID.flatMap({ apps[$0] }) {
            chain.append(Profile(kind: .app(app.name), entries: entries))
        }
        chain.append(standard)
        return chain
    }

    private mutating func parseSettings(_ section: TOMLTable) -> Settings {
        var result = Settings()
        for key in section.keys {
            guard let value = section[key] else { continue }
            switch key {
            case "scroll_speed":
                if let number = value.double ?? value.int.map(Double.init) {
                    result.scrollSpeed = number
                } else {
                    warnings.append("settings.scroll_speed must be a number")
                }
            case "rotate_step":
                if let number = value.int ?? value.double.map({ Int($0.rounded()) }), number > 0 {
                    result.rotateStep = number
                } else {
                    warnings.append("settings.rotate_step must be a positive number")
                }
            case "midi_channel":
                if let number = value.int, (1...16).contains(number) {
                    result.midiChannel = number
                } else {
                    warnings.append("settings.midi_channel must be a number from 1 to 16")
                }
            case "midi_cc_per_turn":
                if let number = value.double ?? value.int.map(Double.init), number > 0 {
                    result.midiCCPerTurn = number
                } else {
                    warnings.append("settings.midi_cc_per_turn must be a positive number")
                }
            case "midi_relative":
                if let encoding = value.string.flatMap(MIDIRelativeEncoding.init(rawValue:)) {
                    result.midiRelative = encoding
                } else {
                    warnings.append("settings.midi_relative must be \"twos\" or \"offset\"")
                }
            default:
                break
            }
        }
        return result
    }

    private mutating func parseProfiles(_ table: TOMLTable?, section: String) -> [String: [String: String]] {
        guard let table else { return [:] }
        var result: [String: [String: String]] = [:]
        for name in table.keys {
            guard let profile = table[name]?.table else {
                warnings.append("\(section).\(name) is not a table")
                continue
            }
            result[name] = parseProfile(profile, name: "\(section).\(name)")
        }
        return result
    }

    private mutating func parseProfile(_ table: TOMLTable, name: String) -> [String: String] {
        var entries: [String: String] = [:]
        for event in table.keys {
            if let action = table[event]?.string {
                entries[event] = action
            } else {
                warnings.append("\(name).\(event) is not a string")
            }
        }
        return entries
    }
}
