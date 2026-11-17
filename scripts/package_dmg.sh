#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCH_TARGET="${1:-both}" # arm64 | x86_64 | both
REPO_SLUG="${GITHUB_REPOSITORY:-}"
FEED_URL="${SUBRADAR_UPDATE_FEED_URL:-}"

if [[ -z "$FEED_URL" && -n "$REPO_SLUG" ]]; then
    FEED_URL="https://github.com/${REPO_SLUG}/releases/latest/download/latest.json"
fi

CLEAN_VERSION="${VERSION#v}"
mkdir -p "$DIST_DIR"

generate_icns() {
    local output_icns="$1"
    local work_dir="$ROOT_DIR/.build/dmg-icon"
    local iconset_dir="$work_dir/AppIcon.iconset"
    local base_png="$work_dir/SubRadarIcon1024.png"

    rm -rf "$work_dir"
    mkdir -p "$iconset_dir"

    if [[ -f "$ROOT_DIR/AppConfig/AppIcon.icns" ]]; then
        cp "$ROOT_DIR/AppConfig/AppIcon.icns" "$output_icns"
        return 0
    fi

    swift - "$base_png" <<'SWIFT'
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments[1]
let size: CGFloat = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
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
let grad = CGGradient(
    colorsSpace: cs,
    colors: [NSColor(red: 0.14, green: 0.17, blue: 0.37, alpha: 1).cgColor,
             NSColor(red: 0.07, green: 0.09, blue: 0.20, alpha: 1).cgColor] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
ctx.restoreGState()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
SWIFT

    for sz in 16 32 128 256 512; do
        sips -z "$sz" "$sz" "$base_png" --out "$iconset_dir/icon_${sz}x${sz}.png" >/dev/null
        sips -z "$((sz * 2))" "$((sz * 2))" "$base_png" --out "$iconset_dir/icon_${sz}x${sz}@2x.png" >/dev/null
    done
    iconutil -c icns "$iconset_dir" -o "$output_icns"
}

package_for_arch() {
    local arch="$1"
    local stage_dir="$ROOT_DIR/.build/package-${arch}"
    local app_bundle="$stage_dir/SubRadar.app"
    local contents_dir="$app_bundle/Contents"
    local macos_dir="$contents_dir/MacOS"
    local resources_dir="$contents_dir/Resources"

    echo "==> Building SubRadarApp (${arch}, Release)..."
    swift build --package-path "$ROOT_DIR" -c release --arch "$arch" --product SubRadarApp

    local bin_dir
    bin_dir="$(swift build --package-path "$ROOT_DIR" -c release --arch "$arch" --show-bin-path)"
    local bin_path="$bin_dir/SubRadarApp"
    local core_bundle="$bin_dir/SubRadar_SubRadarCore.bundle"

    if [[ ! -f "$bin_path" ]]; then
        echo "ERROR: Missing binary at $bin_path" >&2
        exit 1
    fi
    if [[ ! -d "$core_bundle" ]]; then
        echo "ERROR: Missing resource bundle at $core_bundle" >&2
        exit 1
    fi

    rm -rf "$stage_dir"
    mkdir -p "$macos_dir" "$resources_dir"

    cp "$bin_path" "$macos_dir/SubRadarApp"
    cp -R "$core_bundle" "$resources_dir/SubRadar_SubRadarCore.bundle"
    generate_icns "$resources_dir/AppIcon.icns"

    cat > "$contents_dir/Info.plist" <<PLIST
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
    <string>${CLEAN_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SubRadarUpdateFeedURL</key>
    <string>${FEED_URL}</string>
</dict>
</plist>
PLIST

    codesign --force --deep --sign - "$app_bundle"
    codesign --verify --deep --strict "$app_bundle"

    local dmg_stage="$stage_dir/dmg-root"
    mkdir -p "$dmg_stage"
    cp -R "$app_bundle" "$dmg_stage/SubRadar.app"
    ln -s /Applications "$dmg_stage/Applications"

    local dmg_name="SubRadar-v${CLEAN_VERSION}-${arch}.dmg"
    local dmg_path="$DIST_DIR/$dmg_name"
    rm -f "$dmg_path"

    hdiutil create -volname "SubRadar ${CLEAN_VERSION}" \
        -srcfolder "$dmg_stage" \
        -ov -format UDZO \
        "$dmg_path" >/dev/null

    echo "==> Created $dmg_path"
}

case "$ARCH_TARGET" in
    arm64|x86_64)
        package_for_arch "$ARCH_TARGET"
        ;;
    both)
        package_for_arch "arm64"
        package_for_arch "x86_64"
        ;;
    *)
        echo "Usage: $0 [arm64|x86_64|both]" >&2
        exit 2
        ;;
esac

echo "==> Writing SHA256SUMS.txt & latest.json..."
(
    cd "$DIST_DIR"
    shasum -a 256 SubRadar-v"${CLEAN_VERSION}"-*.dmg > SHA256SUMS.txt
)

python3 - "$DIST_DIR" "$CLEAN_VERSION" "$BUILD_NUMBER" "$REPO_SLUG" <<'PY'
import datetime, json, os, sys

dist_dir, version, build_num, repo_slug = sys.argv[1:5]
sums = {}
sum_file = os.path.join(dist_dir, "SHA256SUMS.txt")
if os.path.exists(sum_file):
    with open(sum_file, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 2:
                sums[os.path.basename(parts[1])] = parts[0]

assets = {}
for arch in ("arm64", "x86_64"):
    fname = f"SubRadar-v{version}-{arch}.dmg"
    if fname in sums:
        url = f"https://github.com/{repo_slug}/releases/download/v{version}/{fname}" if repo_slug else fname
        assets[arch] = {"dmgURL": url, "sha256": sums[fname]}

manifest = {
    "version": version,
    "build": int(build_num),
    "publishedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "notes": f"SubRadar v{version}",
    "releasePageURL": f"https://github.com/{repo_slug}/releases/tag/v{version}" if repo_slug else None,
    "assets": assets,
}
with open(os.path.join(dist_dir, "latest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
PY

echo "==> Packaging complete. Output files in $DIST_DIR:"
ls -lh "$DIST_DIR"
