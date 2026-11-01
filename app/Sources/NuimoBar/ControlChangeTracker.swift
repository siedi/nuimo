/// Keeps the value of absolute CCs and the not yet sent part of relative CCs, per channel and controller.
///
/// Rotation is fractional: with `midi_cc_per_turn = 127` one value step needs about 21 rotation units, so
/// slow turns add up until a whole step is reached.
struct ControlChangeTracker {
    private struct Key: Hashable {
        var channel: UInt8
        var controller: UInt8
    }

    private var values: [Key: Double] = [:]
    private var rests: [Key: Double] = [:]

    /// Adds `change` to the absolute value, starting at 0 and clamped to 0–127. Returns the rounded value and
    /// whether it differs from before.
    mutating func turnAbsolute(channel: UInt8, controller: UInt8, by change: Double) -> (value: UInt8, changed: Bool) {
        let key = Key(channel: channel, controller: controller)
        let old = values[key, default: 0]
        let new = min(max(old + change, 0), 127)
        values[key] = new
        let value = UInt8(new.rounded())
        return (value, value != UInt8(old.rounded()))
    }

    /// Adds `change` to the relative rest and returns the whole steps to send now.
    mutating func turnRelative(channel: UInt8, controller: UInt8, by change: Double) -> Int {
        let key = Key(channel: channel, controller: controller)
        let total = rests[key, default: 0] + change
        let steps = Int(total)
        rests[key] = total - Double(steps)
        return steps
    }
}
