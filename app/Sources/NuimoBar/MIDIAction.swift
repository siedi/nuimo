/// A MIDI action from `config.toml`, e.g. `midi:note:36@10` or `midi:cc:21:relative`.
struct MIDIAction: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case note(UInt8)
        /// Absolute value when rotating; 127/0 as trigger or for `hold`.
        case controlChange(UInt8)
        case relativeControlChange(UInt8)
        case fixedControlChange(UInt8, value: UInt8)
        case programChange(UInt8)
    }

    var kind: Kind
    /// Channel 1–16, or `nil` for the setting `midi_channel`.
    var channel: Int?

    init(kind: Kind, channel: Int? = nil) {
        self.kind = kind
        self.channel = channel
    }

    /// Parses the part after `midi:`.
    init(parsing text: String) throws(ActionParseError) {
        var body = Substring(text)
        if let at = text.lastIndex(of: "@") {
            let channelText = String(text[text.index(after: at)...])
            guard let channel = Int(channelText), (1...16).contains(channel) else {
                throw .invalidChannel(channelText)
            }
            self.channel = channel
            body = text[..<at]
        } else {
            channel = nil
        }

        let parts = body.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        switch (parts.first, parts.count) {
        case ("note", 2):
            kind = .note(try Self.number(parts[1]))
        case ("pc", 2):
            kind = .programChange(try Self.number(parts[1]))
        case ("cc", 2):
            if let equals = parts[1].firstIndex(of: "=") {
                kind = .fixedControlChange(
                    try Self.number(String(parts[1][..<equals])),
                    value: try Self.number(String(parts[1][parts[1].index(after: equals)...])))
            } else {
                kind = .controlChange(try Self.number(parts[1]))
            }
        case ("cc", 3) where parts[2] == "relative":
            kind = .relativeControlChange(try Self.number(parts[1]))
        default:
            throw .invalidMIDI(text)
        }
    }

    /// Whether the action works for `rotate` and `rotate_pressed`.
    var isContinuous: Bool {
        switch kind {
        case .controlChange, .relativeControlChange: true
        case .note, .fixedControlChange, .programChange: false
        }
    }

    /// Whether the action works for discrete events.
    var isTrigger: Bool {
        switch kind {
        case .note, .controlChange, .fixedControlChange, .programChange: true
        case .relativeControlChange: false
        }
    }

    /// Whether the action works for `hold`.
    var isHold: Bool {
        switch kind {
        case .note, .controlChange: true
        case .relativeControlChange, .fixedControlChange, .programChange: false
        }
    }

    /// Channel 0–15 for the message.
    func resolvedChannel(default defaultChannel: Int) -> UInt8 {
        UInt8((channel ?? defaultChannel) - 1)
    }

    private static func number(_ text: String) throws(ActionParseError) -> UInt8 {
        guard let value = UInt8(text), value <= 127 else { throw .invalidNumber(text) }
        return value
    }
}
