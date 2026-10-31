@testable import NuimoBar

/// ``Outputs`` that records every call instead of touching the system.
@MainActor
final class RecordingOutputs: Outputs {
    enum Call: Equatable {
        case keys(KeyShortcut)
        case media(MediaKey)
        case scroll(Int, KeyModifiers)
        case shell(String)
        case volume(Double)
        case matrix(MatrixImage, Double)
    }

    private(set) var calls: [Call] = []
    /// Simulated system volume in percent; `nil` means the device has no volume control.
    var volume: Double? = 50

    /// Calls without matrix images, for tests that only care about actions.
    var actions: [Call] {
        calls.filter {
            if case .matrix = $0 { return false }
            return true
        }
    }

    var images: [MatrixImage] {
        calls.compactMap {
            if case .matrix(let image, _) = $0 { return image }
            return nil
        }
    }

    func sendKeys(_ shortcut: KeyShortcut) { calls.append(.keys(shortcut)) }
    func sendMedia(_ key: MediaKey) { calls.append(.media(key)) }
    func scroll(pixels: Int, modifiers: KeyModifiers) { calls.append(.scroll(pixels, modifiers)) }
    func runShell(_ command: String) { calls.append(.shell(command)) }

    func changeVolume(by percent: Double) -> Double? {
        calls.append(.volume(percent))
        guard let current = volume else { return nil }
        volume = min(max(current + percent, 0), 100)
        return volume
    }

    func showMatrix(_ image: MatrixImage, seconds: Double) {
        calls.append(.matrix(image, seconds))
    }
}
