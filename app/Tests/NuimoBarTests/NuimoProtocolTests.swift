import CoreBluetooth
import Foundation
import Testing

@testable import NuimoBar

@MainActor
struct NuimoProtocolTests {
    @Test func buttonPressAndRelease() {
        #expect(NuimoProtocol.decode(Data([1]), from: NuimoProtocol.button) == .button(pressed: true))
        #expect(NuimoProtocol.decode(Data([0]), from: NuimoProtocol.button) == .button(pressed: false))
    }

    @Test(arguments: [
        ([0x2C, 0x01] as [UInt8], 300),
        ([0xD4, 0xFE], -300),
        ([0xFF, 0x7F], 32767),
        ([0x00, 0x80], -32768),
        ([0x05, 0x00, 0x99], 5),
    ])
    func rotationIsSignedLittleEndian(bytes: [UInt8], delta: Int) {
        #expect(NuimoProtocol.decode(Data(bytes), from: NuimoProtocol.rotation) == .rotation(delta))
    }

    @Test func swipeCodesFollowTheNuimoOrder() {
        let names = (0..<12).compactMap { code -> String? in
            guard case .gesture(let gesture) = NuimoProtocol.decode(Data([UInt8(code)]), from: NuimoProtocol.swipe)
            else { return nil }
            return gesture.rawValue
        }
        #expect(
            names == [
                "swipe_left", "swipe_right", "swipe_up", "swipe_down",
                "touch_left", "touch_right", "touch_top", "touch_bottom",
                "longtouch_left", "longtouch_right", "longtouch_top", "longtouch_bottom",
            ])
    }

    @Test func flyLeftAndRight() {
        #expect(NuimoProtocol.decode(Data([0, 120]), from: NuimoProtocol.fly) == .gesture(.flyLeft))
        #expect(NuimoProtocol.decode(Data([1, 120]), from: NuimoProtocol.fly) == .gesture(.flyRight))
    }

    @Test func unknownOrIncompleteDataIsIgnored() {
        #expect(NuimoProtocol.decode(Data([12]), from: NuimoProtocol.swipe) == nil)
        #expect(NuimoProtocol.decode(Data([4, 80]), from: NuimoProtocol.fly) == nil)
        #expect(NuimoProtocol.decode(Data([0x2C]), from: NuimoProtocol.rotation) == nil)
        #expect(NuimoProtocol.decode(Data(), from: NuimoProtocol.button) == nil)
        #expect(NuimoProtocol.decode(Data([1]), from: NuimoProtocol.battery) == nil)
    }

    @Test func batteryLevel() {
        #expect(NuimoProtocol.batteryLevel(Data([82])) == 82)
        #expect(NuimoProtocol.batteryLevel(Data()) == nil)
    }

    @Test func gestureNamesAreUnique() {
        #expect(Set(Gesture.allCases.map(\.rawValue)).count == Gesture.allCases.count)
    }
}
