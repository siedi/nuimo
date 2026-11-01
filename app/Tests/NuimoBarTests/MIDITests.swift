import Testing

@testable import NuimoBar

struct MIDIMessageTests {
    @Test func noteOnAndOff() {
        #expect(MIDIMessage.noteOn(channel: 0, note: 36, velocity: 127).bytes == [0x90, 36, 127])
        #expect(MIDIMessage.noteOff(channel: 9, note: 36).bytes == [0x89, 36, 0])
    }

    @Test func controlAndProgramChange() {
        #expect(MIDIMessage.controlChange(channel: 1, controller: 20, value: 64).bytes == [0xB1, 20, 64])
        #expect(MIDIMessage.programChange(channel: 15, program: 3).bytes == [0xCF, 3])
    }

    @Test func universalPacketIsMIDI1ChannelVoice() {
        #expect(MIDIMessage.noteOn(channel: 0, note: 0x24, velocity: 0x7F).universalPacket == 0x2090_247F)
        #expect(MIDIMessage.programChange(channel: 2, program: 5).universalPacket == 0x20C2_0500)
    }
}

struct MIDIRelativeEncodingTests {
    @Test func twosComplement() {
        #expect(MIDIRelativeEncoding.twos.values(for: 1) == [1])
        #expect(MIDIRelativeEncoding.twos.values(for: -1) == [127])
        #expect(MIDIRelativeEncoding.twos.values(for: -63) == [65])
    }

    @Test func offset() {
        #expect(MIDIRelativeEncoding.offset.values(for: 1) == [65])
        #expect(MIDIRelativeEncoding.offset.values(for: -1) == [63])
        #expect(MIDIRelativeEncoding.offset.values(for: 63) == [127])
    }

    @Test func largeChangesAreSplit() {
        #expect(MIDIRelativeEncoding.twos.values(for: 100) == [63, 37])
        #expect(MIDIRelativeEncoding.offset.values(for: -130) == [1, 1, 60])
        #expect(MIDIRelativeEncoding.twos.values(for: 0) == [])
    }
}

struct MIDIActionTests {
    @Test func parsesAllForms() throws {
        #expect(try Action(parsing: "midi:note:36") == .midi(MIDIAction(kind: .note(36))))
        #expect(try Action(parsing: "midi:note:36@10") == .midi(MIDIAction(kind: .note(36), channel: 10)))
        #expect(try Action(parsing: "midi:cc:20") == .midi(MIDIAction(kind: .controlChange(20))))
        #expect(
            try Action(parsing: "midi:cc:21:relative@2")
                == .midi(MIDIAction(kind: .relativeControlChange(21), channel: 2)))
        #expect(try Action(parsing: "midi:cc:22=64") == .midi(MIDIAction(kind: .fixedControlChange(22, value: 64))))
        #expect(try Action(parsing: "midi:pc:0@16") == .midi(MIDIAction(kind: .programChange(0), channel: 16)))
    }

    @Test func rejectsInvalidForms() {
        #expect(throws: ActionParseError.invalidNumber("128")) { try Action(parsing: "midi:note:128") }
        #expect(throws: ActionParseError.invalidNumber("-1")) { try Action(parsing: "midi:cc:-1") }
        #expect(throws: ActionParseError.invalidNumber("")) { try Action(parsing: "midi:cc:20=") }
        #expect(throws: ActionParseError.invalidChannel("17")) { try Action(parsing: "midi:note:36@17") }
        #expect(throws: ActionParseError.invalidChannel("0")) { try Action(parsing: "midi:pc:1@0") }
        #expect(throws: ActionParseError.invalidMIDI("note")) { try Action(parsing: "midi:note") }
        #expect(throws: ActionParseError.invalidMIDI("cc:20:absolute")) { try Action(parsing: "midi:cc:20:absolute") }
        #expect(throws: ActionParseError.invalidMIDI("sysex:1")) { try Action(parsing: "midi:sysex:1") }
        #expect(throws: ActionParseError.missingArgument("midi")) { try Action(parsing: "midi:") }
    }

    @Test func contexts() throws {
        let cc = try Action(parsing: "midi:cc:20")
        #expect(cc.isContinuous && cc.isTrigger && cc.isHold)
        let relative = try Action(parsing: "midi:cc:20:relative")
        #expect(relative.isContinuous && !relative.isTrigger && !relative.isHold)
        let note = try Action(parsing: "midi:note:1")
        #expect(!note.isContinuous && note.isTrigger && note.isHold)
        let program = try Action(parsing: "midi:pc:1")
        #expect(!program.isContinuous && program.isTrigger && !program.isHold)
        #expect(try !Action(parsing: "keys:a").isHold)
    }

    @Test func channelFallsBackToTheSetting() {
        #expect(MIDIAction(kind: .note(1)).resolvedChannel(default: 1) == 0)
        #expect(MIDIAction(kind: .note(1), channel: 10).resolvedChannel(default: 1) == 9)
    }
}

struct ModeActionTests {
    @Test func parsesAllForms() throws {
        #expect(try Action(parsing: "mode:Resolume") == .mode(.on("Resolume")))
        #expect(try Action(parsing: "mode:off") == .mode(.off))
        #expect(try Action(parsing: "mode:toggle:Resolume Arena") == .mode(.toggle("Resolume Arena")))
        #expect(throws: ActionParseError.missingArgument("mode:toggle")) { try Action(parsing: "mode:toggle:") }
        #expect(throws: ActionParseError.missingArgument("mode")) { try Action(parsing: "mode:") }
    }
}

struct ControlChangeTrackerTests {
    @Test func absoluteStartsAtZeroAndIsClamped() {
        var tracker = ControlChangeTracker()
        #expect(tracker.turnAbsolute(channel: 0, controller: 20, by: -5) == (0, false))
        #expect(tracker.turnAbsolute(channel: 0, controller: 20, by: 100) == (100, true))
        #expect(tracker.turnAbsolute(channel: 0, controller: 20, by: 100) == (127, true))
        #expect(tracker.turnAbsolute(channel: 0, controller: 20, by: 10) == (127, false))
        #expect(tracker.turnAbsolute(channel: 0, controller: 20, by: -27) == (100, true))
    }

    @Test func smallAbsoluteChangesAddUp() {
        var tracker = ControlChangeTracker()
        #expect(tracker.turnAbsolute(channel: 0, controller: 1, by: 0.3) == (0, false))
        #expect(tracker.turnAbsolute(channel: 0, controller: 1, by: 0.3) == (1, true))
    }

    @Test func valuesAreSeparatePerChannelAndController() {
        var tracker = ControlChangeTracker()
        _ = tracker.turnAbsolute(channel: 0, controller: 20, by: 50)
        #expect(tracker.turnAbsolute(channel: 1, controller: 20, by: 1) == (1, true))
        #expect(tracker.turnAbsolute(channel: 0, controller: 21, by: 1) == (1, true))
    }

    @Test func relativeKeepsTheFraction() {
        var tracker = ControlChangeTracker()
        #expect(tracker.turnRelative(channel: 0, controller: 21, by: 0.6) == 0)
        #expect(tracker.turnRelative(channel: 0, controller: 21, by: 0.6) == 1)
        #expect(tracker.turnRelative(channel: 0, controller: 21, by: -2.5) == -2)
        #expect(tracker.turnRelative(channel: 0, controller: 21, by: -0.8) == -1)
    }
}
