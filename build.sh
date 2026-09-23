#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

app='强提醒.app'
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$temporary/AppIcon.iconset"
cp Info.plist "$app/Contents/Info.plist"

sources=(AlarmCore.swift AlertPanel.swift LoginStartup.swift StrongReminder.swift)
swiftc -O -target arm64-apple-macos13 -o "$temporary/arm64" "${sources[@]}"
swiftc -O -target x86_64-apple-macos13 -o "$temporary/x86_64" "${sources[@]}"
lipo -create "$temporary/arm64" "$temporary/x86_64" -output "$app/Contents/MacOS/StrongReminder"

for scale in 16 32 128 256 512; do
    sips -z "$scale" "$scale" AppIcon.png -o "$temporary/AppIcon.iconset/icon_${scale}x${scale}.png" >/dev/null
    twice=$((scale * 2))
    sips -z "$twice" "$twice" AppIcon.png -o "$temporary/AppIcon.iconset/icon_${scale}x${scale}@2x.png" >/dev/null
done
iconutil -c icns "$temporary/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$app"
echo "已生成 $app（Apple Silicon + Intel）"
