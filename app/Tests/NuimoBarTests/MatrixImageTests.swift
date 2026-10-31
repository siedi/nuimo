import Foundation
import Testing

@testable import NuimoBar

/// Expected bytes were generated once with `matrix_bytes` from `nuimo.py`.
struct MatrixImageTests {
    @Test func smileyBytesMatchPython() {
        #expect(
            [UInt8](MatrixImage.smiley.bytes())
                == [0x00, 0x88, 0x10, 0x01, 0x20, 0x88, 0x08, 0x0E, 0x00, 0x00, 0x00, 0xFF, 0x1E])
    }

    @Test func circleBytesMatchPython() {
        #expect(
            [UInt8](MatrixImage.circle.bytes())
                == [0x00, 0x70, 0xF0, 0xF1, 0xE7, 0xCF, 0x1F, 0x1F, 0x1C, 0x00, 0x00, 0xFF, 0x1E])
    }

    @Test func levelFiftyBytesMatchPython() {
        #expect(
            [UInt8](MatrixImage.level(50).bytes())
                == [0x00, 0x00, 0x00, 0x00, 0xF0, 0xE0, 0xFF, 0xFF, 0xFF, 0xFF, 0x01, 0xFF, 0x1E])
    }

    @Test func rotatedArrowWithShortDurationMatchesPython() {
        #expect(
            [UInt8](MatrixImage.arrowUp.bytes(seconds: 0.8))
                == [0x10, 0x70, 0x50, 0x91, 0x04, 0x01, 0x02, 0x04, 0x08, 0x10, 0x00, 0xFF, 0x08])
    }

    @Test func brightnessAndLongDurationMatchPython() {
        #expect(
            [UInt8](MatrixImage.dotBottom.bytes(brightness: 100, seconds: 30))
                == [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1C, 0x38, 0x00, 0x64, 0xFF])
    }

    @Test func levelRoundsHalfToEvenLikePython() {
        // 50 % of 81 pixels is 40.5; Python's round gives 40.
        #expect(MatrixImage.level(50).pixels.count(where: { $0 }) == 40)
    }

    @Test(arguments: [(-10.0, 0), (0.0, 0), (100.0, 81), (250.0, 81)])
    func levelIsClamped(percent: Double, litPixels: Int) {
        #expect(MatrixImage.level(percent).pixels.count(where: { $0 }) == litPixels)
    }

    @Test func levelFillsFromBottomLeft() {
        let pixels = MatrixImage.level(100.0 / 81).pixels
        #expect(pixels[72])
        #expect(pixels.count(where: { $0 }) == 1)
    }

    @Test func fourRotationsGiveTheOriginal() {
        let image = MatrixImage.arrowLeft
        #expect(image.rotated().rotated().rotated().rotated() == image)
        #expect(image.rotated() != image)
    }

    @Test func patternIgnoresWhitespaceAndOtherCharacters() {
        let pattern = String(repeating: "*. ", count: 40) + "*x\n"
        let image = MatrixImage(pattern: pattern)
        #expect(image.pixels.count == 81)
        #expect(image.pixels.first == true)
        #expect(image.pixels[1] == false)
    }
}
