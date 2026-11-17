#!/usr/bin/env bash
set -euo pipefail

# SubRadar 一键安装与升级脚本（不调用 api.github.com，规避未认证 60 次/小时限流）
# 用法: curl -fsSL https://raw.githubusercontent.com/Tianyang17/SubRadar/master/scripts/install.sh | bash
# 可选环境变量: SUBRADAR_REPO=<owner>/<repo>

REPO="${SUBRADAR_REPO:-Tianyang17/SubRadar}"
if [[ -z "$REPO" ]]; then
    echo "请先设置仓库地址，例如: SUBRADAR_REPO=Tianyang17/SubRadar curl -fsSL ... | bash" >&2
    exit 1
fi

ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
    arm64|aarch64) ARCH="arm64" ;;
    x86_64) ARCH="x86_64" ;;
    *)
        echo "不支持的 CPU 架构: $ARCH_RAW" >&2
        exit 1
        ;;
esac

LATEST_JSON_URL="https://github.com/${REPO}/releases/latest/download/latest.json"
TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "==> 正在获取最新发行清单 (${ARCH})..."
curl -fsSL "$LATEST_JSON_URL" -o "$TMP_DIR/latest.json"

PARSED="$(python3 - "$TMP_DIR/latest.json" "$ARCH" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
asset = data.get("assets", {}).get(sys.argv[2], {})
print(data.get("version", ""))
print(asset.get("dmgURL", ""))
print(asset.get("sha256", ""))
PY
)"

VERSION="$(echo "$PARSED" | sed -n '1p')"
DMG_URL="$(echo "$PARSED" | sed -n '2p')"
EXPECTED_SHA="$(echo "$PARSED" | sed -n '3p')"

if [[ -z "$DMG_URL" ]]; then
    echo "ERROR: latest.json 中未找到适用于 ${ARCH} 的 DMG 地址" >&2
    exit 1
fi

DMG_PATH="$TMP_DIR/SubRadar.dmg"
echo "==> 正在下载 SubRadar v${VERSION} (${ARCH})..."
curl -fL --progress-bar "$DMG_URL" -o "$DMG_PATH"

if [[ -n "$EXPECTED_SHA" ]]; then
    ACTUAL_SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
    if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
        echo "ERROR: SHA256 校验失败! 期望=$EXPECTED_SHA 实际=$ACTUAL_SHA" >&2
        exit 1
    fi
    echo "    SHA256 校验通过。"
fi

echo "==> 正在挂载并安装到 /Applications/SubRadar.app..."
MOUNT_DIR="$TMP_DIR/mnt"
mkdir -p "$MOUNT_DIR"
hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_DIR" -nobrowse -readonly -quiet
trap 'hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true; cleanup' EXIT

if [[ ! -d "$MOUNT_DIR/SubRadar.app" ]]; then
    echo "ERROR: DMG 内未找到 SubRadar.app" >&2
    exit 1
fi

TARGET_APP="/Applications/SubRadar.app"
if [[ -w "/Applications" ]]; then
    rm -rf "$TARGET_APP"
    cp -R "$MOUNT_DIR/SubRadar.app" "$TARGET_APP"
    xattr -cr "$TARGET_APP" || true
else
    sudo rm -rf "$TARGET_APP"
    sudo cp -R "$MOUNT_DIR/SubRadar.app" "$TARGET_APP"
    sudo xattr -cr "$TARGET_APP" || true
fi

echo "==> 安装完成：SubRadar v${VERSION} 已就绪（/Applications/SubRadar.app）。"
