import Foundation

/// Queue for the LED matrix: one write at a time, and if images arrive faster than BLE delivers them,
/// only the newest is sent.
///
/// The owner writes the bytes with response and calls ``didWrite()`` from `didWriteValueFor`.
@MainActor
final class MatrixDisplay {
    private let write: @MainActor (Data) -> Void
    private var pending: Data?
    private var isWriting = false

    init(write: @escaping @MainActor (Data) -> Void) {
        self.write = write
    }

    func show(_ image: MatrixImage, seconds: Double = 1.5) {
        pending = image.bytes(seconds: seconds)
        sendIfIdle()
    }

    /// The previous write finished, successfully or not.
    func didWrite() {
        isWriting = false
        sendIfIdle()
    }

    /// Drops a pending image and an unconfirmed write, e.g. after the connection was lost.
    func reset() {
        pending = nil
        isWriting = false
    }

    private func sendIfIdle() {
        guard !isWriting, let frame = pending else { return }
        pending = nil
        isWriting = true
        write(frame)
    }
}
