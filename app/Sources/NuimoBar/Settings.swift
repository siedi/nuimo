/// Values from the `[settings]` section of `config.toml`.
struct Settings: Equatable, Sendable {
    /// Pixels per rotation value for `scroll`; negative reverses the direction.
    var scrollSpeed = 0.5
    /// Rotation value per step for `rotate_left` and `rotate_right`.
    var rotateStep = 300
}
