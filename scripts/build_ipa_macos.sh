#!/usr/bin/env bash
# 一键在 macOS 上打出可自签的未签名 IPA
set -euo pipefail

APP_NAME="QRLinkRouter"
OUT_IPA="${APP_NAME}.ipa"

echo "==> 检查环境"
command -v flutter >/dev/null 2>&1 || { echo "缺少 flutter，请先安装 Flutter SDK"; exit 1; }
command -v pod     >/dev/null 2>&1 || { echo "缺少 CocoaPods，请先 sudo gem install cocoapods"; exit 1; }

echo "==> 清理"
flutter clean
flutter pub get

echo "==> 安装 Pods"
pushd ios >/dev/null
pod install --repo-update
popd >/dev/null

echo "==> 运行单元测试"
flutter test || echo "警告：测试未全部通过，继续打包"

echo "==> 构建 Release（不签名）"
flutter build ios --release --no-codesign

echo "==> 打包 IPA"
rm -rf Payload "${OUT_IPA}"
mkdir -p Payload
cp -R build/ios/iphoneos/Runner.app Payload/
zip -qry "${OUT_IPA}" Payload
rm -rf Payload

echo ""
echo "完成： $(pwd)/${OUT_IPA}"
echo "把这个文件传到 iPhone，用 SideStore / AltStore 自签安装即可。"