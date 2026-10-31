import CoreBluetooth
import Foundation

/// GATT identifiers of the Nuimo and decoding of its sensor notifications. Main actor, because `CBUUID` is not `Sendable`.
@MainActor
enum NuimoProtocol {
    /// A decoded sensor notification.
    enum Input: Equatable, Sendable {
        case button(pressed: Bool)
        /// Signed rotation delta; one full turn is about ``NuimoProtocol/rotationPerTurn``.
        case rotation(Int)
        case gesture(Gesture)
    }

    static let fly = CBUUID(string: "f29b1526-cb19-40f3-be5c-7241ecb82fd2")
    static let swipe = CBUUID(string: "f29b1527-cb19-40f3-be5c-7241ecb82fd2")
    static let rotation = CBUUID(string: "f29b1528-cb19-40f3-be5c-7241ecb82fd2")
    static let button = CBUUID(string: "f29b1529-cb19-40f3-be5c-7241ecb82fd2")
    static let ledMatrix = CBUUID(string: "f29b1524-cb19-40f3-be5c-7241ecb82fd1")
    static let battery = CBUUID(string: "2a19")

    /// Characteristics whose notifications carry user input.
    static let sensors = [fly, swipe, rotation, button]

    /// Approximate rotation value of one full turn.
    static let rotationPerTurn = 2650

    /// Swipe codes 0–11 in the order the Nuimo sends them.
    static let swipeGestures: [Gesture] = [
        .swipeLeft, .swipeRight, .swipeUp, .swipeDown,
        .touchLeft, .touchRight, .touchTop, .touchBottom,
        .longTouchLeft, .longTouchRight, .longTouchTop, .longTouchBottom,
    ]

    /// Fly codes; code 4 (up/down) is not used.
    static let flyGestures: [UInt8: Gesture] = [0: .flyLeft, 1: .flyRight]

    /// Decodes a notification, or returns `nil` for unknown characteristics, codes and short payloads.
    static func decode(_ data: Data, from characteristic: CBUUID) -> Input? {
        let bytes = [UInt8](data)
        switch characteristic {
        case button:
            guard let first = bytes.first else { return nil }
            return .button(pressed: first != 0)
        case rotation:
            guard bytes.count >= 2 else { return nil }
            return .rotation(Int(Int16(bitPattern: UInt16(bytes[0]) | UInt16(bytes[1]) << 8)))
        case swipe:
            guard let code = bytes.first, Int(code) < swipeGestures.count else { return nil }
            return .gesture(swipeGestures[Int(code)])
        case fly:
            guard let code = bytes.first, let gesture = flyGestures[code] else { return nil }
            return .gesture(gesture)
        default:
            return nil
        }
    }

    /// Battery level in percent from the battery characteristic.
    static func batteryLevel(_ data: Data) -> Int? {
        data.first.map(Int.init)
    }
}
