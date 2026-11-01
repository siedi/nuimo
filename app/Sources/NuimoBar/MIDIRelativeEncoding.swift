/// Encoding of relative CC changes, setting `midi_relative`.
enum MIDIRelativeEncoding: String, CaseIterable, Sendable {
    /// Two's complement: 1 = +1, 127 = −1.
    case twos
    /// Offset 64: 65 = +1, 63 = −1.
    case offset

    /// Largest change in one message.
    static let maxStep = 63

    /// CC values for a change of `steps`, split into messages of at most ±63.
    func values(for steps: Int) -> [UInt8] {
        var remaining = steps
        var result: [UInt8] = []
        while remaining != 0 {
            let step = min(max(remaining, -Self.maxStep), Self.maxStep)
            remaining -= step
            result.append(encode(step))
        }
        return result
    }

    private func encode(_ step: Int) -> UInt8 {
        switch self {
        case .twos: UInt8(step >= 0 ? step : 128 + step)
        case .offset: UInt8(64 + step)
        }
    }
}
