#!/bin/bash
# 一键构建 + 安装 + 启动到已连接的 iPhone。
#
# 用法：
#   ./Tools/install_device.sh                # 自动使用默认设备（本机已配对的 iPhone Air）
#   ./Tools/install_device.sh <设备UDID>      # 指定设备
#
# 首次安装后需要在 iPhone 上信任开发者证书：
#   设置 → 通用 → VPN 与设备管理 → “Apple Development: …” → 信任
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="GTIIT.xcodeproj"
SCHEME="GTIIT"
BUNDLE_ID="io.github.optmst0118.gtiit"
DEVICE_ID="${1:-YOUR_DEVICE_UDID}"
DERIVED="/tmp/GTIIT-DD-Device"

echo "==> 构建（设备：${DEVICE_ID}）"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
  -destination "platform=iOS,id=${DEVICE_ID}" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -derivedDataPath "$DERIVED" build | tail -5

APP="${DERIVED}/Build/Products/Debug-iphoneos/GTIIT.app"
echo "==> 安装"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

echo "==> 启动"
if ! xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"; then
  cat <<'EOF'

启动被拒绝，通常是证书还没在手机上被信任。请：

  1. 打开 iPhone「设置」
  2. 通用 → VPN 与设备管理（旧系统：描述文件与设备管理）
  3. 在「开发者 App」里点你的 Apple ID → 信任
  4. 重新运行：./Tools/install_device.sh

免费个人团队的描述文件 7 天后过期，重跑本脚本会自动续签。
EOF
  exit 1
fi

echo "==> 完成，App 已在 iPhone 上启动"
