import CoreBluetooth
import Foundation

/// Bluetooth connection to the Nuimo: finds it, keeps a pending connection open, subscribes to its sensors,
/// reads the battery and writes the LED matrix.
///
/// The first time, the app scans for a device named "Nuimo" and stores its identifier. After that it asks
/// CoreBluetooth to connect to that identifier; the request stays open without a timeout until the Nuimo wakes
/// up, and is renewed right after every disconnect.
@MainActor
final class NuimoDevice: NSObject {
    static let deviceName = "Nuimo"
    /// The Nuimo shows its own check mark animation after connecting; images sent earlier get overwritten.
    static let welcomeDelay: Duration = .seconds(2)
    /// Interval for reading the battery if the characteristic does not support notifications.
    static let batteryPollInterval: Duration = .seconds(600)
    /// Pause before retrying after a failed connection attempt.
    static let retryDelay: Duration = .seconds(2)
    static let identifierKey = "nuimoIdentifier"

    var onStatusChange: ((ConnectionStatus) -> Void)?
    var onBatteryLevel: ((Int) -> Void)?
    var onInput: ((NuimoProtocol.Input) -> Void)?
    /// Called when the matrix accepts images, ``welcomeDelay`` after it was found.
    var onReady: (() -> Void)?

    private(set) var status: ConnectionStatus = .searching {
        didSet {
            if status != oldValue {
                log("Status: \(status)")
                onStatusChange?(status)
            }
        }
    }

    private let defaults: UserDefaults
    private let scheduler: any Scheduler
    private let log: DebugLog
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var matrix: CBCharacteristic?
    private var battery: CBCharacteristic?
    private var isMatrixReady = false
    private var welcomeTimer: ScheduledAction?
    private var batteryTimer: ScheduledAction?
    private var retryTimer: ScheduledAction?
    private lazy var display = MatrixDisplay { [weak self] frame in
        self?.writeMatrix(frame)
    }

    init(defaults: UserDefaults = .standard, scheduler: any Scheduler, log: DebugLog) {
        self.defaults = defaults
        self.scheduler = scheduler
        self.log = log
    }

    /// Creates the central manager. The first call triggers the Bluetooth permission prompt.
    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    /// Shows an image on the matrix. Ignored until the Nuimo is connected and ready.
    func show(_ image: MatrixImage, seconds: Double = 1.5) {
        guard isMatrixReady else { return }
        display.show(image, seconds: seconds)
    }

    private var storedIdentifier: UUID? {
        get { defaults.string(forKey: Self.identifierKey).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: Self.identifierKey) }
    }

    private func connectToKnownOrScan(_ central: CBCentralManager) {
        status = .searching
        if let identifier = storedIdentifier,
            let known = central.retrievePeripherals(withIdentifiers: [identifier]).first
        {
            log("Requesting connection to known Nuimo \(identifier)")
            connect(known, using: central)
        } else {
            log("Scanning for a device named \(Self.deviceName)")
            central.scanForPeripherals(withServices: nil)
        }
    }

    private func connect(_ peripheral: CBPeripheral, using central: CBCentralManager) {
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    private func forgetConnection() {
        welcomeTimer?.cancel()
        batteryTimer?.cancel()
        retryTimer?.cancel()
        welcomeTimer = nil
        batteryTimer = nil
        retryTimer = nil
        matrix = nil
        battery = nil
        isMatrixReady = false
        display.reset()
    }

    private func writeMatrix(_ frame: Data) {
        guard let peripheral, let matrix else {
            display.reset()
            return
        }
        peripheral.writeValue(frame, for: matrix, type: .withResponse)
    }

    private func matrixFound(_ characteristic: CBCharacteristic) {
        matrix = characteristic
        welcomeTimer?.cancel()
        welcomeTimer = scheduler.schedule(after: Self.welcomeDelay) { [weak self] in
            guard let self, self.matrix != nil else { return }
            self.isMatrixReady = true
            self.onReady?()
        }
    }

    private func batteryFound(_ characteristic: CBCharacteristic, on peripheral: CBPeripheral) {
        battery = characteristic
        peripheral.readValue(for: characteristic)
        if characteristic.properties.contains(.notify) {
            peripheral.setNotifyValue(true, for: characteristic)
        } else {
            scheduleBatteryPoll()
        }
    }

    private func scheduleBatteryPoll() {
        batteryTimer = scheduler.schedule(after: Self.batteryPollInterval) { [weak self] in
            guard let self, let peripheral = self.peripheral, let battery = self.battery else { return }
            peripheral.readValue(for: battery)
            self.scheduleBatteryPoll()
        }
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}

extension NuimoDevice: @MainActor CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("Bluetooth state: \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            connectToKnownOrScan(central)
        case .poweredOff:
            forgetConnection()
            peripheral = nil
            status = .bluetoothOff
        case .unauthorized:
            status = .unauthorized
        case .unsupported:
            status = .unsupported
        default:
            status = .searching
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        guard name == Self.deviceName else { return }
        log("Found \(Self.deviceName) \(peripheral.identifier), RSSI \(rssi)")
        central.stopScan()
        storedIdentifier = peripheral.identifier
        connect(peripheral, using: central)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Connected to \(peripheral.identifier)")
        status = .connected
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        log("Connection failed: \(error?.localizedDescription ?? "unknown error")")
        forgetConnection()
        status = .searching
        retryTimer = scheduler.schedule(after: Self.retryDelay) { [weak self] in
            guard let self, let central = self.central, central.state == .poweredOn else { return }
            self.connectToKnownOrScan(central)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        log("Disconnected: \(error?.localizedDescription ?? "no error")")
        forgetConnection()
        status = .searching
        guard central.state == .poweredOn else { return }
        // Renew the pending request right away; it completes as soon as the Nuimo is reachable again.
        connect(peripheral, using: central)
    }
}

extension NuimoDevice: @MainActor CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        if let error {
            log("Service discovery failed: \(error.localizedDescription)")
        }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        if let error {
            log("Characteristic discovery failed for \(service.uuid): \(error.localizedDescription)")
        }
        for characteristic in service.characteristics ?? [] {
            let uuid = characteristic.uuid
            if NuimoProtocol.sensors.contains(uuid) {
                peripheral.setNotifyValue(true, for: characteristic)
            } else if uuid == NuimoProtocol.ledMatrix {
                matrixFound(characteristic)
            } else if uuid == NuimoProtocol.battery {
                batteryFound(characteristic, on: peripheral)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        if let error {
            log("Read failed for \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else { return }
        log("Received \(characteristic.uuid): \(Self.hex(data))")
        if characteristic.uuid == NuimoProtocol.battery {
            if let level = NuimoProtocol.batteryLevel(data) {
                onBatteryLevel?(level)
            }
        } else if let input = NuimoProtocol.decode(data, from: characteristic.uuid) {
            onInput?(input)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        if let error {
            log("Write failed for \(characteristic.uuid): \(error.localizedDescription)")
        }
        if characteristic.uuid == NuimoProtocol.ledMatrix {
            display.didWrite()
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        if let error {
            log("Subscribing to \(characteristic.uuid) failed: \(error.localizedDescription)")
        }
    }
}
