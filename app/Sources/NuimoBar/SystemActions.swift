import AppKit
import CoreGraphics

/// Keyboard, media key and scroll events for other apps, and shell commands.
///
/// Events go to the HID event tap. Without the Accessibility permission they are dropped silently.
@MainActor
enum SystemActions {
    static func sendKeys(_ shortcut: KeyShortcut) {
        let flags = eventFlags(shortcut.modifiers)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: shortcut.keyCode, keyDown: isDown) else {
                continue
            }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    static func sendMedia(_ key: MediaKey) {
        // NX_SYSDEFINED with subtype 8 (aux control buttons); 0xA00 is key down, 0xB00 key up.
        for state in [0xA00, 0xB00] {
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: (key.code << 16) | state,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    static func scroll(pixels: Int, modifiers: KeyModifiers) {
        let amount = Int32(clamping: pixels)
        guard
            let event = CGEvent(
                scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: amount, wheel2: 0, wheel3: 0)
        else { return }
        if !modifiers.isEmpty {
            event.flags = eventFlags(modifiers)
        }
        event.post(tap: .cghidEventTap)
    }

    /// Runs the command with a login shell, so paths like Homebrew's apply. Does not wait for it.
    static func runShell(_ command: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    private static func eventFlags(_ modifiers: KeyModifiers) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        return flags
    }
}
