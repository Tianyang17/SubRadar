import AppKit
import Foundation
import SubRadarCore

/// 将国内外常用软件/服务预设渲染为标准 256x256 圆角 PNG 品牌图标
@MainActor
public enum SoftwarePresetIconRenderer {
    public static func renderPNG(for preset: PopularSoftwarePreset, dimension: Int = 256) -> Data? {
        if let bundled = PopularSoftwarePresetManager.bundledIconData(for: preset) {
            return bundled
        }
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: dimension,
                pixelsHigh: dimension,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ), let graphicsCtx = NSGraphicsContext(bitmapImageRep: rep)
        else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsCtx
        defer { NSGraphicsContext.restoreGraphicsState() }

        let size = NSSize(width: dimension, height: dimension)
        let ctx = graphicsCtx.cgContext
        let rect = NSRect(origin: .zero, size: size)
        let baseColor = NSColor(hexString: preset.accentHex) ?? NSColor(red: 0.31, green: 0.37, blue: 0.84, alpha: 1)
        let lightColor = baseColor.blended(withFraction: 0.14, of: .white) ?? baseColor
        let darkColor = baseColor.blended(withFraction: 0.28, of: .black) ?? baseColor

        // 柔和三段线性背景渐变
        let path = NSBezierPath(
            roundedRect: rect, xRadius: CGFloat(dimension) * 0.22, yRadius: CGFloat(dimension) * 0.22)
        path.addClip()
        if let gradient = NSGradient(colors: [lightColor, baseColor, darkColor]) {
            gradient.draw(in: rect, angle: -52)
        } else {
            baseColor.setFill()
            rect.fill()
        }

        // 顶部微妙高光边缘
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.26).cgColor)
        ctx.setLineWidth(max(2, CGFloat(dimension) * 0.015))
        let insetRect = rect.insetBy(dx: 2, dy: 2)
        let innerPath = NSBezierPath(
            roundedRect: insetRect, xRadius: CGFloat(dimension) * 0.21, yRadius: CGFloat(dimension) * 0.21)
        innerPath.stroke()

        // 优先绘制高辨识度文字徽标（短字符如 GPT / CLD / QQ / B站）
        let text = preset.monogram
        let fontSize: CGFloat =
            text.count >= 4
            ? CGFloat(dimension) * 0.25 : (text.count == 3 ? CGFloat(dimension) * 0.30 : CGFloat(dimension) * 0.36)
        let font =
            NSFont(name: "JetBrainsMono-Bold", size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attrStr.draw(in: textRect)

        return rep.representation(using: .png, properties: [:])
    }
}

extension NSColor {
    fileprivate convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else {
            return nil
        }
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
