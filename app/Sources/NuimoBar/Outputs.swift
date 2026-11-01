/// Everything the controller does outside itself. The app uses ``SystemOutputs``, tests record the calls.
@MainActor
protocol Outputs {
    func sendKeys(_ shortcut: KeyShortcut)
    func sendMedia(_ key: MediaKey)
    func scroll(pixels: Int, modifiers: KeyModifiers)
    func runShell(_ command: String)
    /// Changes the system volume by `percent` points and returns the new volume in percent, or `nil` if the
    /// output device has no volume control.
    func changeVolume(by percent: Double) -> Double?
    func showMatrix(_ image: MatrixImage, seconds: Double)
    func sendMIDI(_ message: MIDIMessage)
}
