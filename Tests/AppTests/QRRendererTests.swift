import Cocoa
import CoreImage

public enum QRRendererTests {
    private static func decode(_ image: CGImage) -> String? {
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: CIImage(cgImage: image)) ?? []
        return (features.first as? CIQRCodeFeature)?.messageString
    }

    private static func makeLogo() -> CGImage {
        let context = CGContext(
            data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: 0.9, green: 0.1, blue: 0.2, alpha: 1))
        context.fillEllipse(in: CGRect(x: 0, y: 0, width: 400, height: 200))
        return context.makeImage()!
    }

    private static func expectError(_ expected: QRError, _ block: () throws -> Void) {
        do {
            try block()
            assertionFailure("Expected \(expected)")
        } catch {
            assert((error as? QRError) == expected, "Expected \(expected), got \(error)")
        }
    }

    public static func run(testRunner: (String, () throws -> Void) -> Void) {
        let url = "https://example.com/some/path?query=1&other=ąęść"

        testRunner("Default render is 1000 x 1000 px") {
            let image = try QRRenderer.render(text: url, correction: .high, options: QRRenderOptions())
            assert(image.width == 1000 && image.height == 1000, "Got \(image.width)x\(image.height)")
        }

        testRunner("Render honours arbitrary sizes") {
            for size in [57, 333, 1000, 2048] {
                let image = try QRRenderer.render(text: url, correction: .medium, options: QRRenderOptions(size: size))
                assert(image.width == size && image.height == size, "Size \(size) gave \(image.width)x\(image.height)")
            }
        }

        testRunner("Matrix is upright: finder patterns at top-left, top-right, bottom-left") {
            let matrix = try QRRenderer.matrix(for: url, correction: .high)
            let last = matrix.count - 1
            assert((0..<7).allSatisfy { matrix[0, $0] && matrix[$0, 0] }, "Top-left finder missing")
            assert((0..<7).allSatisfy { matrix[0, last - $0] }, "Top-right finder missing")
            assert((0..<7).allSatisfy { matrix[last, $0] }, "Bottom-left finder missing")
            assert(!matrix[7, 7] && !matrix[7, last - 7] && !matrix[last - 7, 7], "Finder separators should be light")
        }

        testRunner("Rendered code decodes back to the original text") {
            let image = try QRRenderer.render(text: url, correction: .medium, options: QRRenderOptions())
            let decoded = decode(image)
            assert(decoded == url, "Decoded \(decoded ?? "nil")")
        }

        testRunner("Code with a logo at the default size still decodes") {
            let options = QRRenderOptions(logo: makeLogo())
            let image = try QRRenderer.render(text: url, correction: .high, options: options)
            let decoded = decode(image)
            assert(decoded == url, "Decoded \(decoded ?? "nil")")
        }

        testRunner("Code with the largest logo still decodes") {
            let options = QRRenderOptions(logo: makeLogo(), logoScale: QRRenderer.logoScaleRange.upperBound)
            let image = try QRRenderer.render(text: url, correction: .high, options: options)
            let decoded = decode(image)
            assert(decoded == url, "Decoded \(decoded ?? "nil")")
        }

        testRunner("Empty text is rejected") {
            expectError(.emptyText) { _ = try QRRenderer.matrix(for: "", correction: .high) }
        }

        testRunner("Text over capacity is rejected") {
            let tooLong = String(repeating: "x", count: 5000)
            expectError(.textTooLong) { _ = try QRRenderer.matrix(for: tooLong, correction: .high) }
        }

        testRunner("Sizes below one pixel per module or above the maximum are rejected") {
            let matrix = try QRRenderer.matrix(for: url, correction: .high)
            let minimum = matrix.count + 8
            expectError(.sizeTooSmall(minimum: minimum)) { _ = try QRRenderer.render(matrix, options: QRRenderOptions(size: minimum - 1)) }
            expectError(.invalidSize) { _ = try QRRenderer.render(matrix, options: QRRenderOptions(size: QRRenderer.maximumSize + 1)) }
            _ = try QRRenderer.render(matrix, options: QRRenderOptions(size: minimum))
        }

        testRunner("Window regenerates from pasted text and saves PNG at full size") {
            let controller = QRWindowController()
            assert(!controller.hasQRCode, "No code before text is entered")
            assert(controller.requestedSize == QRWindowController.defaultSize, "Default size should be 1000")

            controller.textView.string = url
            controller.regenerate()
            assert(controller.hasQRCode, "Code should be generated")

            controller.sizeField.stringValue = "1500"
            controller.regenerate()
            let full = try controller.renderFullSize()
            assert(full.width == 1500 && full.height == 1500, "Full size render should use the requested size")
            let png = QRWindowController.pngData(for: full)
            let rep = png.flatMap(NSBitmapImageRep.init(data:))
            assert(rep?.pixelsWide == 1500 && rep?.pixelsHigh == 1500, "PNG should be 1500 px")

            controller.sizeField.stringValue = "abc"
            controller.regenerate()
            assert(!controller.hasQRCode, "Invalid size disables output")
        }

        testRunner("Matrix subscript out of bounds safely returns false without crashing") {
            let matrix = try QRRenderer.matrix(for: url, correction: .high)
            assert(!matrix[-1, 0], "Negative row should return false")
            assert(!matrix[0, -1], "Negative column should return false")
            assert(!matrix[matrix.count, 0], "Row >= count should return false")
            assert(!matrix[0, matrix.count], "Column >= count should return false")
            assert(!matrix[9999, 9999], "Far out of bounds should return false")
        }

        testRunner("Adversarial logo scale (NaN, infinite, negative) renders safely") {
            let logo = makeLogo()
            for scale in [CGFloat.nan, CGFloat.infinity, -1.0, 99.0] {
                let options = QRRenderOptions(logo: logo, logoScale: scale)
                let image = try QRRenderer.render(text: url, correction: .high, options: options)
                assert(image.width == 1000 && image.height == 1000, "Render with scale \(scale) should produce valid image")
            }
        }

        testRunner("Multibyte Unicode and emoji characters encode and decode accurately") {
            let emojiText = "🌟 QR Code with 🚀 emojis and ñ, ü, 日本語, 🍺"
            let image = try QRRenderer.render(text: emojiText, correction: .quartile, options: QRRenderOptions())
            let decoded = decode(image)
            assert(decoded == emojiText, "Decoded '\(decoded ?? "nil")' should match '\(emojiText)'")
        }
    }
}
