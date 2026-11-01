import Testing

@testable import NuimoBar

struct ConnectionStatusTests {
    @Test func connectedShowsBatteryWhenKnown() {
        #expect(ConnectionStatus.connected.menuText(batteryLevel: 82) == "Connected · Battery 82 %")
        #expect(ConnectionStatus.connected.menuText(batteryLevel: nil) == "Connected")
    }

    @Test func otherStatesIgnoreTheBattery() {
        #expect(ConnectionStatus.searching.menuText(batteryLevel: 50) == "Searching for Nuimo … (press once)")
        #expect(ConnectionStatus.bluetoothOff.menuText(batteryLevel: nil) == "Bluetooth is off")
        #expect(ConnectionStatus.unauthorized.menuText(batteryLevel: nil) == "Bluetooth not allowed")
        #expect(ConnectionStatus.unsupported.menuText(batteryLevel: nil) == "Bluetooth unavailable")
    }

    @Test func onlyConnectedIsConnected() {
        let states: [ConnectionStatus] = [.searching, .connected, .bluetoothOff, .unauthorized, .unsupported]
        #expect(states.filter(\.isConnected) == [.connected])
    }
}
