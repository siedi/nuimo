import Testing

@testable import NuimoBar

struct ActionTests {
    @Test func keysWithModifiers() throws {
        #expect(try Action(parsing: "keys:opt+return") == .keys(KeyShortcut(keyCode: 36, modifiers: .option)))
        #expect(
            try Action(parsing: "keys:cmd+shift+4") == .keys(KeyShortcut(keyCode: 21, modifiers: [.command, .shift])))
        #expect(try Action(parsing: "keys:tab") == .keys(KeyShortcut(keyCode: 48, modifiers: [])))
    }

    @Test func keysIgnoreCaseAndAcceptAlt() throws {
        #expect(
            try Action(parsing: "keys:Ctrl+ALT+F5") == .keys(KeyShortcut(keyCode: 96, modifiers: [.control, .option])))
    }

    @Test func keysErrors() {
        #expect(throws: ActionParseError.unknownKey("ä")) { try Action(parsing: "keys:cmd+ä") }
        #expect(throws: ActionParseError.unknownModifier("hyper")) { try Action(parsing: "keys:hyper+a") }
        #expect(throws: ActionParseError.missingArgument("keys")) { try Action(parsing: "keys:") }
        #expect(throws: ActionParseError.missingArgument("keys")) { try Action(parsing: "keys:cmd+") }
        #expect(throws: ActionParseError.missingArgument("keys")) { try Action(parsing: "keys") }
    }

    @Test func media() throws {
        #expect(try Action(parsing: "media:playpause") == .media(.playPause))
        #expect(try Action(parsing: "media:next") == .media(.next))
        #expect(throws: ActionParseError.unknownMediaKey("louder")) { try Action(parsing: "media:louder") }
    }

    @Test func shellKeepsTheWholeCommand() throws {
        #expect(try Action(parsing: "shell:shortcuts run 'Licht: an'") == .shell("shortcuts run 'Licht: an'"))
        #expect(throws: ActionParseError.missingArgument("shell")) { try Action(parsing: "shell:") }
    }

    @Test func continuousActions() throws {
        #expect(try Action(parsing: "volume") == .volume)
        #expect(try Action(parsing: "scroll") == .scroll([]))
        #expect(try Action(parsing: "scroll:ctrl+opt") == .scroll([.control, .option]))
        #expect(throws: ActionParseError.unexpectedArgument("volume")) { try Action(parsing: "volume:10") }
        #expect(throws: ActionParseError.unknownModifier("")) { try Action(parsing: "scroll:") }
    }

    @Test func noneAndUnknown() throws {
        #expect(try Action(parsing: "none") == .none)
        #expect(throws: ActionParseError.unknownAction("midi:note:36")) { try Action(parsing: "midi:note:36") }
        #expect(throws: ActionParseError.unknownAction("")) { try Action(parsing: "") }
    }

    @Test func contexts() throws {
        #expect(try Action(parsing: "volume").isContinuous)
        #expect(try !Action(parsing: "volume").isTrigger)
        #expect(try Action(parsing: "keys:a").isTrigger)
        #expect(try !Action(parsing: "keys:a").isContinuous)
        #expect(try Action(parsing: "none").isTrigger && Action(parsing: "none").isContinuous)
    }

    @Test func everyDocumentedKeyIsKnown() {
        let keys =
            Array("abcdefghijklmnopqrstuvwxyz0123456789-=[]\\;',./`").map(String.init)
            + [
                "return", "enter", "tab", "space", "delete", "forwarddelete", "escape", "home", "end", "pageup",
                "pagedown", "left", "right", "up", "down",
            ]
            + (1...20).map { "f\($0)" }
        #expect(keys.filter { KeyShortcut.keyCodes[$0] == nil } == [])
        #expect(Set(KeyShortcut.keyCodes.values).count == KeyShortcut.keyCodes.count)
    }
}
