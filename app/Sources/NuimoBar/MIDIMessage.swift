/// A MIDI 1.0 channel voice message. Channels are 0–15 here, 1–16 in `config.toml`.
enum MIDIMessage: Equatable, Sendable {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8)
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case programChange(channel: UInt8, program: UInt8)

    /// The message as MIDI 1.0 bytes.
    var bytes: [UInt8] {
        switch self {
        case .noteOn(let channel, let note, let velocity):
            [0x90 | channel & 0x0F, note & 0x7F, velocity & 0x7F]
        case .noteOff(let channel, let note):
            [0x80 | channel & 0x0F, note & 0x7F, 0]
        case .controlChange(let channel, let controller, let value):
            [0xB0 | channel & 0x0F, controller & 0x7F, value & 0x7F]
        case .programChange(let channel, let program):
            [0xC0 | channel & 0x0F, program & 0x7F]
        }
    }

    /// The message as a 32-bit Universal MIDI Packet (type 2, MIDI 1.0 channel voice, group 0).
    var universalPacket: UInt32 {
        let bytes = bytes
        let data2 = bytes.count > 2 ? UInt32(bytes[2]) : 0
        return 0x2000_0000 | UInt32(bytes[0]) << 16 | UInt32(bytes[1]) << 8 | data2
    }
}
