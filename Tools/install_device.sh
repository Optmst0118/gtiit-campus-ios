#!/bin/bash
# 一键构建 + 安装 + 启动到已连接的 iPhone。
#
# 用法：
#   ./Tools/install_device.sh            # 自动选择已连接的实体设备
#   ./Tools/install_device.sh <设备UDID>  # 指定设备
#
# 签名团队按以下顺序读取：
#   1. 环境变量 DEVELOPMENT_TEAM
#   2. Tools/signing.env 的 DEVELOPMENT_TEAM=（本机文件，不进入 Git）
#   3. 工程里已有的 DEVELOPMENT_TEAM
#
# 首次安装后需要在 iPhone 上信任开发者证书：
#   设置 → 通用 → VPN 与设备管理 → “Apple Development: …” → 信任
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="GTIIT.xcodeproj"
SCHEME="GTIIT"
BUNDLE_ID="io.github.optmst0118.gtiit.beta"
DERIVED="${TMPDIR:-/tmp}/GTIIT-DD-Device"

# --- 选择设备 ---
DEVICE_ID="${1:-}"
if [ -z "${DEVICE_ID}" ]; then
  echo "==> 未指定设备，查找已连接的实体 iPhone"
  xcrun devicectl list devices --json-output /tmp/gtiit-devices.json >/dev/null 2>&1 || true
  DEVICE_ID="$(python3 - <<'PY'
import json
try:
    data = json.load(open("/tmp/gtiit-devices.json"))
except Exception:
    raise SystemExit(0)
for device in data.get("result", {}).get("devices", []):
    hardware = device.get("hardwareProperties", {})
    if hardware.get("reality") == "physical":
        print(hardware.get("udid", ""))
        break
PY
)"
fi
if [ -z "${DEVICE_ID}" ]; then
  echo "找不到已连接的 iPhone。请先用数据线连接并解锁设备，然后重试，或手动传入 UDID："
  echo "  xcrun devicectl list devices"
  exit 1
fi

# --- 读取签名团队 ---
TEAM="${DEVELOPMENT_TEAM:-}"
if [ -z "${TEAM}" ] && [ -f Tools/signing.env ]; then
  TEAM="$(sed -n 's/^DEVELOPMENT_TEAM=//p' Tools/signing.env | head -1)"
fi
if [ -z "${TEAM}" ]; then
  echo "提示：没有找到 DEVELOPMENT_TEAM。请在 Xcode 的 Signing & Capabilities 选择 Team，"
  echo "      或运行 cp Tools/signing.env.example Tools/signing.env 并填入团队 ID。"
fi

echo "==> 构建（设备：${DEVICE_ID}，团队：${TEAM:-工程默认}）"
BUILD_CMD=(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -configuration Debug
  -destination "platform=iOS,id=${DEVICE_ID}"
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration
  -derivedDataPath "${DERIVED}")
if [ -n "${TEAM}" ]; then
  BUILD_CMD+=("DEVELOPMENT_TEAM=${TEAM}")
fi
"${BUILD_CMD[@]}" build | tail -5

APP="${DERIVED}/Build/Products/Debug-iphoneos/GTIIT.app"
# Never install an original-channel artifact from the independent Beta branch.
ACTUAL_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
if [ "$ACTUAL_ID" != "$BUNDLE_ID" ]; then
  echo "安装已停止：App 标识与 Beta 通道不匹配。"
  exit 1
fi
python3 Tools/verify_bundle.py "$APP"
echo "==> 安装独立 GTIIT Beta"
xcrun devicectl device install app --device "${DEVICE_ID}" "${APP}"

echo "==> 启动"
if ! xcrun devicectl device process launch --device "${DEVICE_ID}" --terminate-existing "${BUNDLE_ID}"; then
  cat <<'EOF'

启动被拒绝，通常是证书还没在手机上被信任。请：

  1. 打开 iPhone「设置」
  2. 通用 → VPN 与设备管理（旧系统：描述文件与设备管理）
  3. 在「开发者 App」里点你的 Apple ID → 信任
  4. 重新运行：./Tools/install_device.sh
EOF
  exit 1
fi

echo "==> 完成，App 已在 iPhone 上启动"
