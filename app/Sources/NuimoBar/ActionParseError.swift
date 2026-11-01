/// Why an action from `config.toml` could not be parsed. Descriptions go to the debug log.
enum ActionParseError: Error, Equatable, CustomStringConvertible {
    case unknownAction(String)
    case unknownKey(String)
    case unknownModifier(String)
    case unknownMediaKey(String)
    case missingArgument(String)
    case unexpectedArgument(String)
    case invalidMIDI(String)
    case invalidNumber(String)
    case invalidChannel(String)

    var description: String {
        switch self {
        case .unknownAction(let text): "unknown action '\(text)'"
        case .unknownKey(let key): "unknown key '\(key)'"
        case .unknownModifier(let name): "unknown modifier '\(name)'"
        case .unknownMediaKey(let name): "unknown media key '\(name)'"
        case .missingArgument(let kind): "'\(kind)' needs an argument"
        case .unexpectedArgument(let kind): "'\(kind)' takes no argument"
        case .invalidMIDI(let text): "invalid MIDI action 'midi:\(text)'"
        case .invalidNumber(let text): "'\(text)' is not a number from 0 to 127"
        case .invalidChannel(let text): "'\(text)' is not a MIDI channel from 1 to 16"
        }
    }
}
