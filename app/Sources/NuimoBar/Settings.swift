/// Values from the `[settings]` section of `config.toml`.
struct Settings: Equatable, Sendable {
    /// Pixels per rotation value for `scroll`; negative reverses the direction.
    var scrollSpeed = 0.5
    /// Rotation value per step for `rotate_left` and `rotate_right`.
    var rotateStep = 300
    /// MIDI channel 1–16 for actions without their own channel.
    var midiChannel = 1
    /// Change of an absolute CC value per full turn.
    var midiCCPerTurn = 127.0
    var midiRelative = MIDIRelativeEncoding.twos
}
