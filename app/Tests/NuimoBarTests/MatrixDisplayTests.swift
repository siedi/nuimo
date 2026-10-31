import Foundation
import Testing

@testable import NuimoBar

@MainActor
struct MatrixDisplayTests {
    let writes = WriteRecorder()
    let display: MatrixDisplay

    init() {
        display = MatrixDisplay { [writes] in writes.frames.append($0) }
    }

    @Test func firstImageIsWrittenImmediately() {
        display.show(.smiley, seconds: 1)
        #expect(writes.frames == [MatrixImage.smiley.bytes(seconds: 1)])
    }

    @Test func newestImageWinsWhileAWriteIsPending() {
        display.show(.smiley)
        display.show(.level(10))
        display.show(.level(20))
        display.show(.level(30))
        #expect(writes.frames.count == 1)
        display.didWrite()
        #expect(writes.frames == [MatrixImage.smiley.bytes(seconds: 1.5), MatrixImage.level(30).bytes(seconds: 1.5)])
        display.didWrite()
        #expect(writes.frames.count == 2)
    }

    @Test func resetDropsPendingImageAndAllowsTheNextWrite() {
        display.show(.smiley)
        display.show(.circle)
        display.reset()
        display.didWrite()
        #expect(writes.frames.count == 1)
        display.show(.twoDots)
        #expect(writes.frames.last == MatrixImage.twoDots.bytes(seconds: 1.5))
    }
}

@MainActor
final class WriteRecorder {
    var frames: [Data] = []
}
