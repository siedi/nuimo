import Foundation

/// A 9×9 image for the Nuimo's LED matrix, row by row from the top left.
struct MatrixImage: Equatable, Sendable {
    static let size = 9
    static let pixelCount = size * size

    private(set) var pixels: [Bool]

    init(pixels: [Bool]) {
        precondition(pixels.count == Self.pixelCount, "a matrix image needs \(Self.pixelCount) pixels")
        self.pixels = pixels
    }

    /// Builds an image from a 9×9 pattern of `*` (on) and `.` (off); all other characters are ignored.
    init(pattern: String) {
        self.init(pixels: pattern.compactMap { $0 == "*" ? true : $0 == "." ? false : nil })
    }

    /// The image rotated 90° clockwise.
    func rotated() -> MatrixImage {
        let n = Self.size
        var result = [Bool](repeating: false, count: Self.pixelCount)
        for row in 0..<n {
            for col in 0..<n {
                result[row * n + col] = pixels[(n - 1 - col) * n + row]
            }
        }
        return MatrixImage(pixels: result)
    }

    /// A fill gauge for 0–100 %, row by row from the bottom.
    ///
    /// Rounds half to even like Python's `round`, so the pixel count matches `nuimo.py`.
    static func level(_ percent: Double) -> MatrixImage {
        let clamped = min(max(percent, 0), 100)
        let count = Int((clamped / 100 * Double(pixelCount)).rounded(.toNearestOrEven))
        var pixels = [Bool](repeating: false, count: pixelCount)
        for k in 0..<count {
            pixels[(size - 1 - k / size) * size + k % size] = true
        }
        return MatrixImage(pixels: pixels)
    }

    /// The 13 bytes for the matrix characteristic: 81 pixel bits in 11 bytes, brightness, display time in 1/10 s.
    func bytes(brightness: UInt8 = 255, seconds: Double = 3.0) -> Data {
        var data = [UInt8](repeating: 0, count: 11)
        for (index, isOn) in pixels.enumerated() where isOn {
            data[index / 8] |= 1 << (index % 8)
        }
        let tenths = UInt8(min(255, max(0, Int(seconds * 10))))
        return Data(data + [brightness, tenths])
    }
}

extension MatrixImage {
    static let smiley = MatrixImage(
        pattern: """
            .........
            ..*...*..
            ..*...*..
            .........
            .*.....*.
            ..*...*..
            ...***...
            .........
            .........
            """)

    static let circle = MatrixImage(
        pattern: """
            .........
            ...***...
            ..*****..
            .*******.
            .*******.
            .*******.
            ..*****..
            ...***...
            .........
            """)

    static let twoDots = MatrixImage(
        pattern: """
            .........
            .........
            .........
            .**...**.
            .**...**.
            .........
            .........
            .........
            .........
            """)

    static let arrowLeft = MatrixImage(
        pattern: """
            .........
            ...*.....
            ..*......
            .*.......
            *********
            .*.......
            ..*......
            ...*.....
            .........
            """)
    static let arrowUp = arrowLeft.rotated()
    static let arrowRight = arrowUp.rotated()
    static let arrowDown = arrowRight.rotated()

    static let dotLeft = MatrixImage(
        pattern: """
            .........
            .........
            .........
            **.......
            **.......
            **.......
            .........
            .........
            .........
            """)
    static let dotTop = dotLeft.rotated()
    static let dotRight = dotTop.rotated()
    static let dotBottom = dotRight.rotated()

    /// Shown when a mode is switched on.
    static let modeOn = MatrixImage(
        pattern: """
            .........
            .*.....*.
            .**...**.
            .*.*.*.*.
            .*..*..*.
            .*.....*.
            .*.....*.
            .*.....*.
            .........
            """)

    /// Shown when a mode is switched off.
    static let modeOff = MatrixImage(
        pattern: """
            .........
            .*.....*.
            ..*...*..
            ...*.*...
            ....*....
            ...*.*...
            ..*...*..
            .*.....*.
            .........
            """)
}
