import CoreMIDI
import Foundation

/// Virtual MIDI source named "Nuimo" that other apps such as Resolume see as an input.
///
/// The unique ID is created once and kept in `UserDefaults`, so other apps recognise their mappings after a
/// restart.
@MainActor
final class MIDIOut {
    static let sourceName = "Nuimo"
    static let uniqueIDKey = "midiUniqueID"

    private let defaults: UserDefaults
    private let log: DebugLog
    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()

    init(defaults: UserDefaults = .standard, log: DebugLog) {
        self.defaults = defaults
        self.log = log
    }

    /// Creates the client and the virtual source.
    func start() {
        guard source == 0 else { return }
        var status = MIDIClientCreateWithBlock("NuimoBar" as CFString, &client, nil)
        guard status == noErr else {
            log("Creating the MIDI client failed: \(status)")
            return
        }
        status = MIDISourceCreateWithProtocol(client, Self.sourceName as CFString, ._1_0, &source)
        guard status == noErr else {
            log("Creating the MIDI source failed: \(status)")
            source = 0
            return
        }
        assignUniqueID()
        log("MIDI source \(Self.sourceName) ready")
    }

    func send(_ message: MIDIMessage) {
        guard source != 0 else { return }
        var list = MIDIEventList()
        var word = message.universalPacket
        withUnsafeMutablePointer(to: &list) { listPointer in
            let packet = MIDIEventListInit(listPointer, ._1_0)
            _ = MIDIEventListAdd(listPointer, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &word)
            let status = MIDIReceivedEventList(source, listPointer)
            if status != noErr {
                log("Sending MIDI failed: \(status)")
            }
        }
    }

    private func assignUniqueID() {
        if let stored = defaults.object(forKey: Self.uniqueIDKey) as? Int,
            MIDIObjectSetIntegerProperty(source, kMIDIPropertyUniqueID, MIDIUniqueID(truncatingIfNeeded: stored))
                == noErr
        {
            return
        }
        // No ID yet, or another device took it: pick a new one.
        for _ in 0..<10 {
            let candidate = MIDIUniqueID.random(in: 1...MIDIUniqueID.max)
            if MIDIObjectSetIntegerProperty(source, kMIDIPropertyUniqueID, candidate) == noErr {
                defaults.set(Int(candidate), forKey: Self.uniqueIDKey)
                return
            }
        }
        log("Could not assign a MIDI unique ID")
    }
}
