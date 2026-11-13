#!/bin/bash
# Сборка SnowDesk. Запуск: bash build.sh
# Автор: VovkaProdigy96 · Лицензия CC BY-NC 4.0
set -e
cd "$(dirname "$0")"

if ! xcode-select -p >/dev/null 2>&1 || ! command -v swiftc >/dev/null 2>&1; then
  echo "❄️  Нужны бесплатные инструменты разработчика Apple."
  echo "   Сейчас откроется окно — нажми «Установить» и дождись окончания (5–15 минут)."
  echo "   Потом снова запусти: bash build.sh"
  xcode-select --install || true
  exit 1
fi

APP="SnowDesk.app"
echo "❄️  Собираю приложение…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 main.swift Prefs.swift Snowfall.swift World.swift Autumn.swift Summer.swift Spring.swift Tour.swift -o "$APP/Contents/MacOS/SnowDesk" -framework AppKit -framework SwiftUI

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>SnowDesk</string>
  <key>CFBundleIdentifier</key><string>io.github.vovkaprodigy96.snowdesk</string>
  <key>CFBundleName</key><string>SnowDesk</string>
  <key>CFBundleDisplayName</key><string>SnowDesk</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>3.0</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 VovkaProdigy96 · CC BY-NC 4.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

mkdir -p "$APP/Contents/Resources"
cp scene/* "$APP/Contents/Resources/"

if [ -f car.png ]; then
  mkdir -p "$APP/Contents/Resources"
  cp car.png "$APP/Contents/Resources/car.png"
  echo "🚙 Нашёл car.png — снег будет чистить твоя машина!"
fi

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "✅ Готово! Запускаю. Значок сезона (❄️ 🌸 ☀️ 🍂) — в строке меню справа вверху."
open "$APP"
