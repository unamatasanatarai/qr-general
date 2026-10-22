import AppKit
import CoreGraphics

func generateDMGBackground(scale: CGFloat, outputPath: String) {
    let ptWidth: CGFloat = 660
    let ptHeight: CGFloat = 400
    let pxWidth = Int(ptWidth * scale)
    let pxHeight = Int(ptHeight * scale)
    
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pxWidth,
        pixelsHigh: pxHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: pxWidth * 4,
        bitsPerPixel: 32
    )!
    rep.size = NSSize(width: ptWidth, height: ptHeight)
    
    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Failed to create NSGraphicsContext")
    }
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    
    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    cg.interpolationQuality = .high
    
    // Invert coordinate system to match top-left (0,0)
    cg.translateBy(x: 0, y: ptHeight)
    cg.scaleBy(x: 1.0, y: -1.0)
    
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    
    func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        return NSColor(calibratedRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
    }
    
    // 1. Military Tactical Dark Slate Background Gradient
    let bgColors = [
        rgb(20, 27, 38).cgColor,
        rgb(12, 17, 24).cgColor,
        rgb(7, 10, 15).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.55, 1.0]
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        cg.drawLinearGradient(bgGrad, start: CGPoint(x: ptWidth * 0.5, y: 0), end: CGPoint(x: ptWidth * 0.5, y: ptHeight), options: [])
    }
    
    // 2. Subtle Military Tactical Radar / Coordinate Grid
    cg.saveGState()
    cg.setStrokeColor(rgb(255, 255, 255, 0.022).cgColor)
    cg.setLineWidth(1.0)
    for x in stride(from: 30, through: Int(ptWidth) - 30, by: 36) {
        cg.move(to: CGPoint(x: CGFloat(x), y: 25))
        cg.addLine(to: CGPoint(x: CGFloat(x), y: ptHeight - 25))
    }
    for y in stride(from: 30, through: Int(ptHeight) - 30, by: 36) {
        cg.move(to: CGPoint(x: 25, y: CGFloat(y)))
        cg.addLine(to: CGPoint(x: ptWidth - 25, y: CGFloat(y)))
    }
    cg.strokePath()
    cg.restoreGState()
    
    // 3. Tactical Frame, Military Corner Brackets & Scale Marks
    let borderRect = CGRect(x: 14, y: 14, width: ptWidth - 28, height: ptHeight - 28)
    let framePath = NSBezierPath(roundedRect: borderRect, xRadius: 10, yRadius: 10)
    rgb(229, 175, 40, 0.22).setStroke()
    framePath.lineWidth = 1.0
    framePath.stroke()
    
    // Hairline outer perimeter
    let outerPath = NSBezierPath(rect: CGRect(x: 0.5, y: 0.5, width: ptWidth - 1, height: ptHeight - 1))
    rgb(255, 255, 255, 0.07).setStroke()
    outerPath.lineWidth = 1.0
    outerPath.stroke()
    
    // Corner brackets
    func drawBracket(x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat) {
        let b = NSBezierPath()
        b.move(to: CGPoint(x: x, y: y + dy * 18))
        b.line(to: CGPoint(x: x, y: y))
        b.line(to: CGPoint(x: x + dx * 18, y: y))
        b.lineWidth = 2.4
        rgb(229, 175, 40, 0.75).setStroke()
        b.stroke()
    }
    drawBracket(x: 20, y: 20, dx: 1, dy: 1)
    drawBracket(x: ptWidth - 20, y: 20, dx: -1, dy: 1)
    drawBracket(x: 20, y: ptHeight - 20, dx: 1, dy: -1)
    drawBracket(x: ptWidth - 20, y: ptHeight - 20, dx: -1, dy: -1)
    
    // 4. Icon Target Reticles (App at x=180, y=196; Applications at x=480, y=196)
    let yCenter: CGFloat = 196
    let appX: CGFloat = 180
    let appsX: CGFloat = 480
    
    func drawDockingZone(at center: CGPoint, isDestination: Bool) {
        cg.saveGState()
        
        // Soft ambient glow
        let glowColors = (isDestination
            ? [rgb(229, 175, 40, 0.16).cgColor, rgb(229, 175, 40, 0.0).cgColor]
            : [rgb(120, 170, 240, 0.12).cgColor, rgb(120, 170, 240, 0.0).cgColor]) as CFArray
        if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
            cg.drawRadialGradient(glowGrad, startCenter: center, startRadius: 15, endCenter: center, endRadius: 70, options: [])
        }
        
        // Rounded squircle docking platform
        let sqRect = CGRect(x: center.x - 56, y: center.y - 56, width: 112, height: 112)
        let sqPath = NSBezierPath(roundedRect: sqRect, xRadius: 26, yRadius: 26)
        rgb(18, 24, 34, 0.6).setFill()
        sqPath.fill()
        
        (isDestination ? rgb(229, 175, 40, 0.35) : rgb(150, 185, 230, 0.22)).setStroke()
        sqPath.lineWidth = 1.2
        sqPath.stroke()
        
        // Reticle ticks
        let cross = NSBezierPath()
        let rIn: CGFloat = 60
        let rOut: CGFloat = 70
        cross.move(to: CGPoint(x: center.x - rOut, y: center.y))
        cross.line(to: CGPoint(x: center.x - rIn, y: center.y))
        cross.move(to: CGPoint(x: center.x + rIn, y: center.y))
        cross.line(to: CGPoint(x: center.x + rOut, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - rOut))
        cross.line(to: CGPoint(x: center.x, y: center.y - rIn))
        cross.move(to: CGPoint(x: center.x, y: center.y + rIn))
        cross.line(to: CGPoint(x: center.x, y: center.y + rOut))
        cross.lineWidth = 1.6
        (isDestination ? rgb(229, 175, 40, 0.55) : rgb(150, 185, 230, 0.35)).setStroke()
        cross.stroke()
        
        cg.restoreGState()
    }
    
    drawDockingZone(at: CGPoint(x: appX, y: yCenter), isDestination: false)
    drawDockingZone(at: CGPoint(x: appsX, y: yCenter), isDestination: true)
    
    // 5. Dynamic Guided Trajectories between App & Applications
    let pStart = CGPoint(x: appX + 56, y: yCenter)
    let pEnd = CGPoint(x: appsX - 56, y: yCenter)
    
    // Primary golden trajectory arc
    let stream1 = NSBezierPath()
    stream1.move(to: pStart)
    stream1.curve(to: pEnd, controlPoint1: CGPoint(x: 275, y: yCenter - 14), controlPoint2: CGPoint(x: 385, y: yCenter + 14))
    stream1.setLineDash([5, 4], count: 2, phase: 0)
    stream1.lineWidth = 1.6
    rgb(229, 175, 40, 0.40).setStroke()
    stream1.stroke()
    
    // Secondary upper & lower particle streams
    let streamUpper = NSBezierPath()
    streamUpper.move(to: CGPoint(x: pStart.x + 6, y: yCenter - 18))
    streamUpper.curve(to: CGPoint(x: pEnd.x - 6, y: yCenter - 16), controlPoint1: CGPoint(x: 285, y: yCenter - 34), controlPoint2: CGPoint(x: 375, y: yCenter - 2))
    streamUpper.setLineDash([3, 5], count: 2, phase: 0)
    streamUpper.lineWidth = 1.0
    rgb(160, 200, 240, 0.25).setStroke()
    streamUpper.stroke()
    
    let streamLower = NSBezierPath()
    streamLower.move(to: CGPoint(x: pStart.x + 6, y: yCenter + 18))
    streamLower.curve(to: CGPoint(x: pEnd.x - 6, y: yCenter + 16), controlPoint1: CGPoint(x: 285, y: yCenter + 2), controlPoint2: CGPoint(x: 375, y: yCenter + 34))
    streamLower.setLineDash([3, 5], count: 2, phase: 0)
    streamLower.lineWidth = 1.0
    rgb(229, 175, 40, 0.25).setStroke()
    streamLower.stroke()
    
    // 6. Flying QR Code Squares Swarm
    // Dispersed along trajectories with dynamic scale, opacity, and rotation
    struct FlyingModule {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let alpha: CGFloat
        let isGold: Bool
        let isFinder: Bool
    }
    
    let swarm: [FlyingModule] = [
        // App departure burst
        FlyingModule(x: 240, y: yCenter - 24, size: 7.0, alpha: 0.70, isGold: false, isFinder: false),
        FlyingModule(x: 246, y: yCenter + 16, size: 8.5, alpha: 0.85, isGold: true,  isFinder: false),
        FlyingModule(x: 252, y: yCenter - 6,  size: 5.5, alpha: 0.60, isGold: false, isFinder: false),
        FlyingModule(x: 258, y: yCenter - 34, size: 9.0, alpha: 0.75, isGold: false, isFinder: false),
        FlyingModule(x: 264, y: yCenter + 28, size: 6.5, alpha: 0.80, isGold: true,  isFinder: false),
        FlyingModule(x: 270, y: yCenter - 16, size: 13.0, alpha: 0.95, isGold: true, isFinder: true), // Mini Finder
        
        // Mid-trajectory approach
        FlyingModule(x: 278, y: yCenter + 8,  size: 7.0, alpha: 0.70, isGold: false, isFinder: false),
        FlyingModule(x: 284, y: yCenter - 28, size: 8.0, alpha: 0.80, isGold: false, isFinder: false),
        FlyingModule(x: 290, y: yCenter + 22, size: 10.0, alpha: 0.90, isGold: true, isFinder: false),
        FlyingModule(x: 298, y: yCenter - 10, size: 5.0, alpha: 0.65, isGold: false, isFinder: false),
        FlyingModule(x: 306, y: yCenter + 14, size: 6.5, alpha: 0.75, isGold: true,  isFinder: false),
        FlyingModule(x: 312, y: yCenter - 22, size: 8.5, alpha: 0.80, isGold: false, isFinder: false),
        
        // Around center command arrow
        FlyingModule(x: 346, y: yCenter + 22, size: 7.5, alpha: 0.80, isGold: true,  isFinder: false),
        FlyingModule(x: 352, y: yCenter - 24, size: 9.0, alpha: 0.85, isGold: false, isFinder: false),
        FlyingModule(x: 358, y: yCenter + 10, size: 6.0, alpha: 0.70, isGold: true,  isFinder: false),
        FlyingModule(x: 366, y: yCenter - 14, size: 14.0, alpha: 0.95, isGold: true, isFinder: true), // Mini Finder
        
        // Applications approach & docking swarm
        FlyingModule(x: 376, y: yCenter + 26, size: 8.0, alpha: 0.80, isGold: false, isFinder: false),
        FlyingModule(x: 384, y: yCenter - 28, size: 10.5, alpha: 0.90, isGold: true, isFinder: false),
        FlyingModule(x: 392, y: yCenter + 12, size: 6.0, alpha: 0.70, isGold: false, isFinder: false),
        FlyingModule(x: 400, y: yCenter - 10, size: 8.5, alpha: 0.85, isGold: true,  isFinder: false),
        FlyingModule(x: 408, y: yCenter + 22, size: 7.0, alpha: 0.75, isGold: false, isFinder: false),
        FlyingModule(x: 416, y: yCenter - 20, size: 11.0, alpha: 0.90, isGold: true, isFinder: false),
        FlyingModule(x: 422, y: yCenter + 6,  size: 5.5, alpha: 0.65, isGold: false, isFinder: false),
        FlyingModule(x: 428, y: yCenter - 8,  size: 8.0, alpha: 0.85, isGold: true,  isFinder: false),
        FlyingModule(x: 434, y: yCenter + 18, size: 6.5, alpha: 0.80, isGold: false, isFinder: false)
    ]
    
    for m in swarm {
        let r = CGRect(x: m.x - m.size / 2, y: m.y - m.size / 2, width: m.size, height: m.size)
        let cr = m.size * 0.22
        let path = NSBezierPath(roundedRect: r, xRadius: cr, yRadius: cr)
        
        if m.isFinder {
            // Nested QR Finder square with gold and obsidian layers
            (m.isGold ? rgb(255, 238, 150, m.alpha) : rgb(225, 238, 255, m.alpha)).setFill()
            path.fill()
            let innerCut = r.insetBy(dx: m.size * 0.24, dy: m.size * 0.24)
            rgb(12, 17, 24).setFill()
            NSBezierPath(roundedRect: innerCut, xRadius: cr * 0.7, yRadius: cr * 0.7).fill()
            let centerDot = r.insetBy(dx: m.size * 0.38, dy: m.size * 0.38)
            (m.isGold ? rgb(255, 238, 150, m.alpha) : rgb(225, 238, 255, m.alpha)).setFill()
            NSBezierPath(roundedRect: centerDot, xRadius: cr * 0.5, yRadius: cr * 0.5).fill()
        } else {
            (m.isGold ? rgb(255, 215, 60, m.alpha) : rgb(180, 205, 235, m.alpha)).setFill()
            path.fill()
            
            // Crisp metallic edge
            (m.isGold ? rgb(255, 252, 210, m.alpha * 0.75) : rgb(255, 255, 255, m.alpha * 0.5)).setStroke()
            path.lineWidth = 0.6
            path.stroke()
        }
    }
    
    // 7. Tactical Military Echelon Chevrons (Directional Arrows)
    func drawChevron(at x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: NSColor, lineWidth: CGFloat) {
        let c = NSBezierPath()
        c.move(to: CGPoint(x: x - width / 2, y: y - height / 2))
        c.line(to: CGPoint(x: x + width / 2, y: y))
        c.line(to: CGPoint(x: x - width / 2, y: y + height / 2))
        c.lineWidth = lineWidth
        c.lineCapStyle = .round
        c.lineJoinStyle = .miter
        color.setStroke()
        c.stroke()
    }
    
    // Flanking multi-chevron stream
    drawChevron(at: 288, y: yCenter, width: 7, height: 14, color: rgb(229, 175, 40, 0.35), lineWidth: 1.8)
    drawChevron(at: 297, y: yCenter, width: 8, height: 16, color: rgb(229, 175, 40, 0.60), lineWidth: 2.0)
    drawChevron(at: 306, y: yCenter, width: 9, height: 18, color: rgb(229, 175, 40, 0.85), lineWidth: 2.2)
    
    drawChevron(at: 354, y: yCenter, width: 9, height: 18, color: rgb(229, 175, 40, 0.85), lineWidth: 2.2)
    drawChevron(at: 363, y: yCenter, width: 8, height: 16, color: rgb(229, 175, 40, 0.60), lineWidth: 2.0)
    drawChevron(at: 372, y: yCenter, width: 7, height: 14, color: rgb(229, 175, 40, 0.35), lineWidth: 1.8)
    
    // 8. Central Gold Command Arrow Capsule
    let pillW: CGFloat = 46
    let pillH: CGFloat = 32
    let pillRect = CGRect(x: 330 - pillW / 2, y: yCenter - pillH / 2, width: pillW, height: pillH)
    let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2)
    
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: rgb(0, 0, 0, 0.80).cgColor)
    rgb(16, 22, 32).setFill()
    pillPath.fill()
    cg.restoreGState()
    
    // Gold metallic bevel on capsule
    let goldGradColors = [
        rgb(255, 245, 180).cgColor,
        rgb(229, 175, 40).cgColor,
        rgb(150, 100, 10).cgColor,
        rgb(245, 195, 55).cgColor
    ] as CFArray
    if let goldGrad = CGGradient(colorsSpace: colorSpace, colors: goldGradColors, locations: [0.0, 0.35, 0.70, 1.0]) {
        cg.saveGState()
        pillPath.addClip()
        cg.setLineWidth(2.0)
        pillPath.stroke()
        cg.drawLinearGradient(goldGrad, start: CGPoint(x: pillRect.minX, y: pillRect.minY), end: CGPoint(x: pillRect.maxX, y: pillRect.maxY), options: [])
        cg.restoreGState()
    }
    
    // Primary Command Arrow
    let mainArrow = NSBezierPath()
    mainArrow.move(to: CGPoint(x: 321, y: yCenter))
    mainArrow.line(to: CGPoint(x: 339, y: yCenter))
    mainArrow.move(to: CGPoint(x: 333, y: yCenter - 5.0))
    mainArrow.line(to: CGPoint(x: 339, y: yCenter))
    mainArrow.line(to: CGPoint(x: 333, y: yCenter + 5.0))
    mainArrow.lineWidth = 2.4
    mainArrow.lineCapStyle = .round
    mainArrow.lineJoinStyle = .round
    rgb(255, 238, 150).setStroke()
    mainArrow.stroke()
    
    // 9. Top Header Banner: Military General Command Status
    func drawHeaderStar(cx: CGFloat, cy: CGFloat, R: CGFloat) {
        let r = R * 0.382
        let path = NSBezierPath()
        for k in 0..<5 {
            let theta = -CGFloat.pi / 2.0 + CGFloat(k) * (2.0 * CGFloat.pi / 5.0)
            let phi = theta + CGFloat.pi / 5.0
            let p1 = CGPoint(x: cx + R * cos(theta), y: cy + R * sin(theta))
            let p2 = CGPoint(x: cx + r * cos(phi), y: cy + r * sin(phi))
            if k == 0 { path.move(to: p1) } else { path.line(to: p1) }
            path.line(to: p2)
        }
        path.close()
        rgb(229, 175, 40, 0.90).setFill()
        path.fill()
    }
    
    // Header stars rank insignia (3-star General) at top
    let headerStarsY: CGFloat = 34
    drawHeaderStar(cx: 330, cy: headerStarsY, R: 5.5)
    drawHeaderStar(cx: 314, cy: headerStarsY, R: 4.0)
    drawHeaderStar(cx: 346, cy: headerStarsY, R: 4.0)
    
    // Invert coordinate system only for NSAttributedString drawing if needed
    cg.translateBy(x: 0, y: ptHeight)
    cg.scaleBy(x: 1.0, y: -1.0)
    
    let pStyle = NSMutableParagraphStyle()
    pStyle.alignment = .center
    
    let headerAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 10.0, weight: .bold),
        .foregroundColor: rgb(229, 175, 40, 0.95),
        .paragraphStyle: pStyle,
        .kern: 2.0
    ]
    let headerStr = NSAttributedString(string: "QR GENERAL  •  TACTICAL DEPLOYMENT", attributes: headerAttrs)
    headerStr.draw(in: CGRect(x: 130, y: ptHeight - 64, width: 400, height: 16))
    
    // Bottom Action Instruction Banner
    let footerAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .bold),
        .foregroundColor: rgb(215, 230, 250, 0.90),
        .paragraphStyle: pStyle,
        .kern: 1.8
    ]
    let footerStr = NSAttributedString(string: "DRAG APPLICATION TO INSTALL", attributes: footerAttrs)
    footerStr.draw(in: CGRect(x: 130, y: ptHeight - 362, width: 400, height: 16))
    
    let subFooterAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 7.5, weight: .regular),
        .foregroundColor: rgb(130, 155, 185, 0.45),
        .paragraphStyle: pStyle,
        .kern: 1.2
    ]
    let subFooterStr = NSAttributedString(string: "ZERO DEPENDENCY  •  AIRDROP READY  •  ARM64 / x86_64", attributes: subFooterAttrs)
    subFooterStr.draw(in: CGRect(x: 130, y: ptHeight - 380, width: 400, height: 14))
    
    NSGraphicsContext.restoreGraphicsState()
    
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to convert image to PNG")
    }
    try! pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Generated: \(outputPath) (\(pxWidth)x\(pxHeight))")
}

generateDMGBackground(scale: 1.0, outputPath: "Resources/dmg_background.png")
generateDMGBackground(scale: 2.0, outputPath: "Resources/dmg_background@2x.png")
