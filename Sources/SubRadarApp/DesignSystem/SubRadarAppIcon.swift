import AppKit
import SwiftUI

/// SubRadar 品牌标识徽章：循环续期弧线 + 精密雷达扫描象限 + 临期提醒信号点（适配 28px 侧边栏与大尺寸占位）
public struct SubRadarBrandMark: View {
    public let size: CGFloat

    public init(size: CGFloat = 28) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.17, blue: 0.36),
                            Color(red: 0.08, green: 0.10, blue: 0.21)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 内部精密雷达扫掠扇区
            Circle()
                .trim(from: 0.0, to: 0.24)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.20, green: 0.78, blue: 0.96).opacity(0.0),
                            Color(red: 0.20, green: 0.78, blue: 0.96).opacity(0.45)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: size * 0.22, lineCap: .butt)
                )
                .frame(width: size * 0.44, height: size * 0.44)
                .rotationEffect(.degrees(-80))

            // 核心周期循环弧线（270° 缺口代表订阅周期延续，右上 1:30 方向开口）
            Circle()
                .trim(from: 0.08, to: 0.84)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white,
                            .white.opacity(0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: max(1.8, size * 0.105), lineCap: .round)
                )
                .frame(width: size * 0.56, height: size * 0.56)
                .rotationEffect(.degrees(-15))

            // 续期提醒发光信号点（位于缺口右上象限）
            Circle()
                .fill(Color(red: 0.20, green: 0.88, blue: 0.74))
                .frame(width: max(4, size * 0.17), height: max(4, size * 0.17))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: max(0.6, size * 0.025))
                )
                .offset(x: size * 0.19, y: -size * 0.19)

            // 中心锚点（订阅日历原点）
            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: max(3.2, size * 0.13), height: max(3.2, size * 0.13))
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: max(0.8, size * 0.03))
        )
        .shadow(
            color: Color(red: 0.12, green: 0.16, blue: 0.42).opacity(0.24), radius: max(2, size * 0.18),
            y: max(1, size * 0.08))
    }
}

/// 运行期生成高分辨率 SubRadar 品牌 Dock 图标（订阅续期循环 + 雷达扫描象限 + 信号点）
enum SubRadarAppIcon {
    @MainActor
    static func makeDockIcon(size: CGFloat = 512) -> NSImage {
        let px = max(64, Int(size))
        let image = NSImage(size: NSSize(width: size, height: size))
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
            ), let graphicsCtx = NSGraphicsContext(bitmapImageRep: rep)
        else {
            return image
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsCtx
        let ctx = graphicsCtx.cgContext

        let inset = size * 0.08
        let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let cornerRadius = rect.width * 0.225

        // 1. 外部柔和投影
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -size * 0.025),
            blur: size * 0.055,
            color: NSColor.black.withAlphaComponent(0.36).cgColor
        )
        let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(bgPath)
        ctx.setFillColor(NSColor(red: 0.08, green: 0.10, blue: 0.21, alpha: 1.0).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // 2. Squircle 深空蓝靛渐变背景
        ctx.saveGState()
        ctx.addPath(bgPath)
        ctx.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bgColors =
            [
                NSColor(red: 0.14, green: 0.18, blue: 0.39, alpha: 1.0).cgColor,
                NSColor(red: 0.10, green: 0.13, blue: 0.28, alpha: 1.0).cgColor,
                NSColor(red: 0.06, green: 0.08, blue: 0.16, alpha: 1.0).cgColor
            ] as CFArray
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.52, 1.0]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: rect.maxY),
                end: CGPoint(x: rect.maxX, y: rect.minY),
                options: []
            )
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)

        // 右上角极光青雷达扫描光晕
        let glowColors =
            [
                NSColor(red: 0.20, green: 0.85, blue: 0.78, alpha: 0.26).cgColor,
                NSColor(red: 0.25, green: 0.45, blue: 0.96, alpha: 0.0).cgColor
            ] as CFArray
        if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
            let pingAnchor = CGPoint(x: center.x + rect.width * 0.19, y: center.y + rect.width * 0.19)
            ctx.drawRadialGradient(
                glow,
                startCenter: pingAnchor,
                startRadius: 0,
                endCenter: pingAnchor,
                endRadius: rect.width * 0.46,
                options: []
            )
        }

        // 3. 外圈精密刻度环 & 内部参考轨道
        let outerGuideRadius = rect.width * 0.36
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.11).cgColor)
        ctx.setLineWidth(size * 0.006)
        ctx.addEllipse(
            in: CGRect(
                x: center.x - outerGuideRadius,
                y: center.y - outerGuideRadius,
                width: outerGuideRadius * 2,
                height: outerGuideRadius * 2
            ))
        ctx.strokePath()

        // 四向精密刻度线
        let tickInner = rect.width * 0.335
        let tickOuter = rect.width * 0.385
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
        ctx.setLineWidth(size * 0.007)
        for angle in [0.0, Double.pi / 2, Double.pi, Double.pi * 1.5] {
            let dx = CGFloat(cos(angle))
            let dy = CGFloat(sin(angle))
            ctx.move(to: CGPoint(x: center.x + dx * tickInner, y: center.y + dy * tickInner))
            ctx.addLine(to: CGPoint(x: center.x + dx * tickOuter, y: center.y + dy * tickOuter))
            ctx.strokePath()
        }

        // 4. 雷达扫描扇形象限
        ctx.saveGState()
        ctx.move(to: center)
        ctx.addArc(
            center: center,
            radius: rect.width * 0.29,
            startAngle: .pi * 0.10,
            endAngle: .pi * 0.38,
            clockwise: false
        )
        ctx.closePath()
        ctx.setFillColor(NSColor(red: 0.20, green: 0.84, blue: 0.78, alpha: 0.20).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // 5. 核心周期循环白弧（270° 续期环）
        let cycleRadius = rect.width * 0.255
        ctx.setLineCap(.round)
        ctx.setLineWidth(size * 0.056)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
        ctx.addArc(
            center: center,
            radius: cycleRadius,
            startAngle: .pi * 0.42,
            endAngle: .pi * 1.94,
            clockwise: false
        )
        ctx.strokePath()

        // 6. 中心订阅日历原点
        let coreRadius = size * 0.044
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.94).cgColor)
        ctx.fillEllipse(
            in: CGRect(
                x: center.x - coreRadius,
                y: center.y - coreRadius,
                width: coreRadius * 2,
                height: coreRadius * 2
            ))

        // 7. 临期续订信号点（翡翠青亮斑，位于缺口右上象限）
        let pingOffset = rect.width * 0.185
        let pingCenter = CGPoint(x: center.x + pingOffset, y: center.y + pingOffset)
        let pingOuterRadius = size * 0.068
        ctx.setFillColor(NSColor(red: 0.20, green: 0.88, blue: 0.74, alpha: 0.28).cgColor)
        ctx.fillEllipse(
            in: CGRect(
                x: pingCenter.x - pingOuterRadius,
                y: pingCenter.y - pingOuterRadius,
                width: pingOuterRadius * 2,
                height: pingOuterRadius * 2
            ))
        let pingRadius = size * 0.046
        ctx.setFillColor(NSColor(red: 0.22, green: 0.90, blue: 0.74, alpha: 1.0).cgColor)
        ctx.fillEllipse(
            in: CGRect(
                x: pingCenter.x - pingRadius,
                y: pingCenter.y - pingRadius,
                width: pingRadius * 2,
                height: pingRadius * 2
            ))

        ctx.restoreGState()

        // 8. 玻璃内描边
        ctx.addPath(bgPath)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.20).cgColor)
        ctx.setLineWidth(size * 0.008)
        ctx.strokePath()

        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(rep)
        return image
    }
}
