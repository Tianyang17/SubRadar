import AppKit
import CoreGraphics

/// 运行期生成锐利单色 Template 菜单栏图标（适配 macOS 浅色/深色系统菜单栏）
enum SubRadarMenuBarIcon {
    @MainActor
    static let templateImage: NSImage = makeTemplateImage()

    @MainActor
    static func makeTemplateImage(pointSize: CGFloat = 18) -> NSImage {
        let scale: CGFloat = 2
        let px = Int(pointSize * scale)
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: px,
                pixelsHigh: px,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "SubRadar")
                ?? NSImage()
        }

        rep.size = NSSize(width: pointSize, height: pointSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            NSGraphicsContext.restoreGraphicsState()
            return image
        }

        let center = CGPoint(x: pointSize / 2, y: pointSize / 2)
        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)

        // 1. 主雷达循环外弧（右上 1:30 方向留出信号缺口）
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineWidth(1.9)
        ctx.addArc(
            center: center,
            radius: pointSize * 0.34,
            startAngle: .pi * 0.44,
            endAngle: .pi * 1.94,
            clockwise: false
        )
        ctx.strokePath()

        // 2. 内层扫描细弧
        ctx.setLineWidth(1.25)
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.68).cgColor)
        ctx.addArc(
            center: center,
            radius: pointSize * 0.20,
            startAngle: .pi * 0.58,
            endAngle: .pi * 1.65,
            clockwise: false
        )
        ctx.strokePath()

        // 3. 中心锚点
        let coreR: CGFloat = 1.65
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillEllipse(
            in: CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)
        )

        // 4. 右上角临期雷达信号点（位于缺口处）
        let pingOffset = pointSize * 0.24
        let pingR: CGFloat = 1.95
        ctx.fillEllipse(
            in: CGRect(
                x: center.x + pingOffset - pingR,
                y: center.y + pingOffset - pingR,
                width: pingR * 2,
                height: pingR * 2
            )
        )

        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}
