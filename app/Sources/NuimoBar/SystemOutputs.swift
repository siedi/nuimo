/// ``Outputs`` for the running app: system events, CoreAudio and the Nuimo's matrix.
@MainActor
struct SystemOutputs: Outputs {
    let device: NuimoDevice
    let log: DebugLog

    func sendKeys(_ shortcut: KeyShortcut) {
        SystemActions.sendKeys(shortcut)
    }

    func sendMedia(_ key: MediaKey) {
        SystemActions.sendMedia(key)
    }

    func scroll(pixels: Int, modifiers: KeyModifiers) {
        SystemActions.scroll(pixels: pixels, modifiers: modifiers)
    }

    func runShell(_ command: String) {
        do {
            try SystemActions.runShell(command)
        } catch {
            log("Shell command failed to start: \(error)")
        }
    }

    func changeVolume(by percent: Double) -> Double? {
        SystemVolume.change(by: percent)
    }

    func showMatrix(_ image: MatrixImage, seconds: Double) {
        device.show(image, seconds: seconds)
    }
}
