import Foundation
import Testing

@testable import NuimoBar

struct ConfigTests {
    static let sample = """
        [settings]
        scroll_speed = -1
        rotate_step = 150.0

        [default]
        rotate = "volume"
        press = "media:playpause"

        [apps.TradingView]
        press = "keys:opt+return"

        [apps."com.apple.Safari"]
        press = "keys:cmd+r"

        [modes.Resolume]
        press = "none"
        """

    let tradingView = FrontmostApp(name: "TradingView", bundleID: "com.tradingview.tradingviewapp.desktop")
    let safari = FrontmostApp(name: "Safari", bundleID: "com.apple.Safari")
    let finder = FrontmostApp(name: "Finder", bundleID: "com.apple.finder")

    @Test func parsesSettingsAndProfiles() throws {
        let config = try Config(parsing: Self.sample)
        #expect(config.settings == Settings(scrollSpeed: -1, rotateStep: 150))
        #expect(config.standard.entries == ["rotate": "volume", "press": "media:playpause"])
        #expect(config.apps["TradingView"] == ["press": "keys:opt+return"])
        #expect(config.modes["Resolume"] == ["press": "none"])
        #expect(config.warnings.isEmpty)
    }

    @Test func missingSectionsUseDefaults() throws {
        let config = try Config(parsing: "")
        #expect(config.settings == Settings())
        #expect(config.profiles(for: finder, mode: nil).map(\.kind) == [.standard])
    }

    @Test func invalidValuesAreSkippedWithWarnings() throws {
        let config = try Config(
            parsing: """
                [settings]
                scroll_speed = "fast"
                rotate_step = 0
                [default]
                press = 1
                swipe_left = "media:previous"
                [apps]
                Broken = "x"
                """)
        #expect(config.settings == Settings())
        #expect(config.standard.entries == ["swipe_left": "media:previous"])
        #expect(config.apps.isEmpty)
        #expect(config.warnings.count == 4)
    }

    @Test func syntaxErrorHasAPosition() {
        #expect {
            try Config(parsing: "[default]\npress = \"keys:a\n")
        } throws: { error in
            guard let error = error as? Config.SyntaxError else { return false }
            return error.line == 2 && error.localizedDescription.hasPrefix("Zeile 2, Spalte")
        }
    }

    @Test func resolutionByAppName() throws {
        let chain = try Config(parsing: Self.sample).profiles(for: tradingView, mode: nil)
        #expect(chain.map(\.kind) == [.app("TradingView"), .standard])
    }

    @Test func resolutionByBundleIDShowsTheAppName() throws {
        let chain = try Config(parsing: Self.sample).profiles(for: safari, mode: nil)
        #expect(chain.map(\.kind) == [.app("Safari"), .standard])
        #expect(chain.first?["press"] == "keys:cmd+r")
    }

    @Test func resolutionFallsBackToStandard() throws {
        let config = try Config(parsing: Self.sample)
        #expect(config.profiles(for: finder, mode: nil).map(\.kind) == [.standard])
        #expect(config.profiles(for: nil, mode: nil).map(\.kind) == [.standard])
    }

    @Test func activeModeComesFirst() throws {
        let chain = try Config(parsing: Self.sample).profiles(for: tradingView, mode: "Resolume")
        #expect(chain.map(\.kind) == [.mode("Resolume"), .app("TradingView"), .standard])
    }

    @Test func unknownModeIsIgnored() throws {
        let chain = try Config(parsing: Self.sample).profiles(for: finder, mode: "Gone")
        #expect(chain.map(\.kind) == [.standard])
    }

    @Test func bundledDefaultConfigParsesWithoutWarnings() throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Resources/default-config.toml")
        let config = try Config(parsing: String(contentsOf: url, encoding: .utf8))
        #expect(config.warnings.isEmpty)
        #expect(config.standard["rotate"] == "volume")
        #expect(config.apps["TradingView"]?["press"] == "keys:opt+return")
        let actions = ([config.standard.entries] + Array(config.apps.values)).flatMap(\.values)
        for text in actions {
            #expect(throws: Never.self) { try Action(parsing: text) }
        }
    }
}
