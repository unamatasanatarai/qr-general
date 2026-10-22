import CoreGraphics
import CoreImage
import Foundation

public enum QRErrorCorrection: String, CaseIterable {
    case low = "L"
    case medium = "M"
    case quartile = "Q"
    case high = "H"

    public var title: String {
        switch self {
        case .low: return "Low (7%)"
        case .medium: return "Medium (15%)"
        case .quartile: return "Quartile (25%)"
        case .high: return "High (30%)"
        }
    }
}

public enum QRError: LocalizedError, Equatable {
    case emptyText
    case textTooLong
    case invalidSize
    case sizeTooSmall(minimum: Int)
    case renderFailed

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Paste or type some text to encode."
        case .textTooLong:
            return "The text is too long for a QR code at this error correction level."
        case .invalidSize:
            return "Size must be a whole number of pixels between 1 and \(QRRenderer.maximumSize)."
        case .sizeTooSmall(let minimum):
            return "Size must be at least \(minimum) px for this much text."
        case .renderFailed:
            return "The QR code could not be rendered."
        }
    }
}

/// The square grid of dark/light modules of a QR symbol, without a quiet zone. Row 0 is the top.
public struct QRMatrix {
    public let count: Int
    private let modules: [Bool]

    init(count: Int, modules: [Bool]) {
        self.count = count
        self.modules = modules
    }

    @inline(__always)
    public subscript(row: Int, column: Int) -> Bool {
        guard row >= 0, row < count, column >= 0, column < count else { return false }
        return modules[row * count + column]
    }
}

public struct QRRenderOptions {
    /// Width and height of the whole image in pixels, quiet zone included.
    public var size: Int
    /// Light border around the symbol, in modules. The QR spec asks for 4.
    public var quietZone: Int
    public var logo: CGImage?
    /// Side of the logo backdrop as a fraction of the symbol width.
    public var logoScale: CGFloat

    public init(size: Int = 1000, quietZone: Int = 4, logo: CGImage? = nil, logoScale: CGFloat = 0.30) {
        self.size = size
        self.quietZone = quietZone
        self.logo = logo
        self.logoScale = logoScale
    }
}

public enum QRRenderer {
    public static let maximumSize = 10_000
    public static let logoScaleRange: ClosedRange<CGFloat> = 0.10...0.40

    private static let ciContext = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])

    public static func matrix(for text: String, correction: QRErrorCorrection) throws -> QRMatrix {
        guard !text.isEmpty else { throw QRError.emptyText }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { throw QRError.renderFailed }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue(correction.rawValue, forKey: "inputCorrectionLevel")
        // Core Image returns no image when the message exceeds the capacity of the largest symbol.
        guard let output = filter.outputImage else { throw QRError.textTooLong }

        // Core Image draws one pixel per module, so read the pixels back as the module grid.
        let extent = output.extent.integral
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else { throw QRError.renderFailed }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        ciContext.render(output, toBitmap: &pixels, rowBytes: width * 4, bounds: extent, format: .RGBA8, colorSpace: nil)

        // Core Image adds its own margin; crop to the dark modules so we control the quiet zone.
        let (count, modules): (Int, [Bool]) = try pixels.withUnsafeBufferPointer { ptr in
            guard let baseAddress = ptr.baseAddress else { throw QRError.renderFailed }

            @inline(__always)
            func isDark(_ x: Int, _ y: Int) -> Bool {
                return baseAddress[(y * width + x) * 4] < 128
            }

            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width where isDark(x, y) {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
            let count = maxX - minX + 1
            guard maxX >= 0, count == maxY - minY + 1 else { throw QRError.renderFailed }

            var modules = [Bool](repeating: false, count: count * count)
            for row in 0..<count {
                let rowOffset = row * count
                let yOffset = (minY + row) * width
                for column in 0..<count {
                    modules[rowOffset + column] = baseAddress[(yOffset + minX + column) * 4] < 128
                }
            }
            return (count, modules)
        }

        return QRMatrix(count: count, modules: modules)
    }

    public static func render(_ matrix: QRMatrix, options: QRRenderOptions) throws -> CGImage {
        let pixels = options.size
        let quietZone = max(options.quietZone, 0)
        let total = matrix.count + 2 * quietZone
        guard (1...maximumSize).contains(pixels) else { throw QRError.invalidSize }
        guard pixels >= total else { throw QRError.sizeTooSmall(minimum: total) }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: pixels,
                  height: pixels,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw QRError.renderFailed
        }

        let side = CGFloat(pixels)
        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)

        context.setFillColor(white)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))

        // Module edges snap to whole pixels so every module is crisp at any image size.
        func edge(_ module: Int) -> CGFloat {
            return (CGFloat(module) * side / CGFloat(total)).rounded()
        }

        context.setShouldAntialias(false)
        context.setFillColor(black)

        var rects = [CGRect]()
        rects.reserveCapacity(matrix.count * 4)

        for row in 0..<matrix.count {
            let top = edge(quietZone + row)
            let bottom = edge(quietZone + row + 1)
            var column = 0
            while column < matrix.count {
                guard matrix[row, column] else {
                    column += 1
                    continue
                }
                let start = column
                while column < matrix.count && matrix[row, column] {
                    column += 1
                }
                let left = edge(quietZone + start)
                let right = edge(quietZone + column)
                // Core Graphics has its origin at the bottom left.
                rects.append(CGRect(x: left, y: side - bottom, width: right - left, height: bottom - top))
            }
        }
        context.fill(rects)

        if let logo = options.logo {
            let symbolStart = edge(quietZone)
            let symbolEnd = edge(quietZone + matrix.count)
            let rawScale = options.logoScale.isFinite ? options.logoScale : 0.30
            let scale = min(max(rawScale, logoScaleRange.lowerBound), logoScaleRange.upperBound)
            let backdropSide = ((symbolEnd - symbolStart) * scale).rounded()
            let center = (symbolStart + symbolEnd) / 2
            let backdrop = CGRect(
                x: center - backdropSide / 2,
                y: side - center - backdropSide / 2,
                width: backdropSide,
                height: backdropSide
            )

            context.setShouldAntialias(true)
            context.interpolationQuality = .high
            let radius = backdropSide * 0.12
            context.addPath(CGPath(roundedRect: backdrop, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.setFillColor(white)
            context.fillPath()

            let box = backdrop.insetBy(dx: backdropSide * 0.05, dy: backdropSide * 0.05)
            let logoWidth = CGFloat(logo.width)
            let logoHeight = CGFloat(logo.height)
            if logoWidth.isFinite && logoHeight.isFinite && logoWidth > 0 && logoHeight > 0 && box.width > 0 && box.height > 0 {
                let fit = min(box.width / logoWidth, box.height / logoHeight)
                let drawSize = CGSize(width: logoWidth * fit, height: logoHeight * fit)
                context.draw(logo, in: CGRect(
                    x: box.midX - drawSize.width / 2,
                    y: box.midY - drawSize.height / 2,
                    width: drawSize.width,
                    height: drawSize.height
                ))
            }
        }

        guard let image = context.makeImage() else { throw QRError.renderFailed }
        return image
    }

    public static func render(text: String, correction: QRErrorCorrection, options: QRRenderOptions) throws -> CGImage {
        return try render(matrix(for: text, correction: correction), options: options)
    }
}
