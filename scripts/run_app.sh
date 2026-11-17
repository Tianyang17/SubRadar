#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/.build/SubRadar.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"

echo "==> [1/4] Building SubRadarApp..."
swift build --package-path "$ROOT_DIR" --product SubRadarApp

BIN_PATH="$(swift build --package-path "$ROOT_DIR" --show-bin-path)/SubRadarApp"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "ERROR: SubRadarApp binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> [2/4] Generating AppIcon.icns..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

BASE_PNG="$ROOT_DIR/.build/SubRadarIcon1024.png"
swift - "$BASE_PNG" <<'SWIFT'
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments[1]
let size: CGFloat = 1024
let px = 1024

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
)!
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let rect = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: size * 0.08, dy: size * 0.08)
let bgPath = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.24, cornerHeight: rect.width * 0.24, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()

let cs = CGColorSpaceCreateDeviceRGB()
let bgGrad = CGGradient(
    colorsSpace: cs,
    colors: [
        NSColor(red: 0.14, green: 0.17, blue: 0.37, alpha: 1).cgColor,
        NSColor(red: 0.07, green: 0.09, blue: 0.20, alpha: 1).cgColor
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(bgGrad, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])

let center = CGPoint(x: rect.midX, y: rect.midY)
ctx.saveGState()
ctx.move(to: center)
ctx.addArc(center: center, radius: rect.width * 0.29, startAngle: .pi * 0.10, endAngle: .pi * 0.38, clockwise: false)
ctx.closePath()
ctx.setFillColor(NSColor(red: 0.20, green: 0.84, blue: 0.78, alpha: 0.22).cgColor)
ctx.fillPath()
ctx.restoreGState()

ctx.setLineCap(.round)
ctx.setLineWidth(size * 0.056)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
ctx.addArc(center: center, radius: rect.width * 0.255, startAngle: .pi * 0.42, endAngle: .pi * 1.94, clockwise: false)
ctx.strokePath()

let coreRadius = size * 0.044
ctx.setFillColor(NSColor.white.withAlphaComponent(0.94).cgColor)
ctx.fillEllipse(in: CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2))

let pingOffset = rect.width * 0.185
let pingCenter = CGPoint(x: center.x + pingOffset, y: center.y + pingOffset)
let pingRadius = size * 0.048
ctx.setFillColor(NSColor(red: 0.22, green: 0.90, blue: 0.74, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: pingCenter.x - pingRadius, y: pingCenter.y - pingRadius, width: pingRadius * 2, height: pingRadius * 2))
ctx.restoreGState()

ctx.addPath(bgPath)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.20).cgColor)
ctx.setLineWidth(size * 0.008)
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()
let pngData = rep.representation(using: .png, properties: [:])!
try pngData.write(to: URL(fileURLWithPath: outPath))
SWIFT

for sz in 16 32 128 256 512; do
    sips -z "$sz" "$sz" "$BASE_PNG" --out "$ICONSET_DIR/icon_${sz}x${sz}.png" >/dev/null
    sz2=$((sz * 2))
    sips -z "$sz2" "$sz2" "$BASE_PNG" --out "$ICONSET_DIR/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

echo "==> [3/4] Assembling SubRadar.app bundle..."
cp "$BIN_PATH" "$MACOS_DIR/SubRadarApp"
BIN_DIR="$(dirname "$BIN_PATH")"
CORE_BUNDLE="$BIN_DIR/SubRadar_SubRadarCore.bundle"
if [[ -d "$CORE_BUNDLE" ]]; then
    rm -rf "$RESOURCES_DIR/SubRadar_SubRadarCore.bundle"
    cp -R "$CORE_BUNDLE" "$RESOURCES_DIR/SubRadar_SubRadarCore.bundle"
fi
cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>SubRadarApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.subradar.desktop</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SubRadar</string>
    <key>CFBundleDisplayName</key>
    <string>SubRadar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "==> [4/4] Launching $APP_BUNDLE..."
open -n "$APP_BUNDLE"
