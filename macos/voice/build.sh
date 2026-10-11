#!/bin/bash
# Build "Bangla Voice.app" — the menu-bar voice-typing companion.
# Usage: ./build.sh [version]   (default 1.0.0)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-1.0.0}"
APPID="com.biswashost.banglavoice"
OUT="$HERE/dist.noindex"   # .noindex so Spotlight/Launchpad do not show the dev build as a 2nd app
APP="$OUT/Bangla Voice.app"

rm -rf "$OUT"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# compile UNIVERSAL (arm64 + x86_64) so Intel Macs can run it too. swiftc builds one
# architecture at a time, so build each and lipo them together. Deployment target matches
# LSMinimumSystemVersion below.
SLICES=()
for A in arm64 x86_64; do
  swiftc -O -target "$A-apple-macosx11.0" "$HERE/Sources/"*.swift -o "$OUT/BanglaVoice-$A" \
    -framework AppKit -framework AVFoundation -framework CoreGraphics -framework Carbon \
    -framework Speech
  SLICES+=("$OUT/BanglaVoice-$A")
done
lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/BanglaVoice"
rm -f "${SLICES[@]}"

# Never ship a single-arch build by accident: that is how the app ended up arm64-only and
# unable to launch on Intel Macs.
HAVE="$(lipo -archs "$APP/Contents/MacOS/BanglaVoice")"
for A in arm64 x86_64; do
  case " $HAVE " in *" $A "*) ;; *) echo "ERROR: binary is missing the $A slice (got: $HAVE)" >&2; exit 1;; esac
done
echo "architectures: $HAVE"

# app icon (reuse the brand flag icon)
cp "$HERE/../src/keylayouts/Bangla Unicode.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Bangla Voice</string>
  <key>CFBundleDisplayName</key><string>Bangla Voice</string>
  <key>CFBundleIdentifier</key><string>$APPID</string>
  <key>CFBundleExecutable</key><string>BanglaVoice</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Bangla Voice listens to your microphone only while a voice mode is on, to type what you say. Nothing is recorded or stored.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>Bangla Voice uses on-device speech recognition for English voice typing. Nothing is recorded or stored.</string>
  <key>NSHumanReadableCopyright</key><string>BiswasHost — MIT. Not affiliated with any commercial keyboard/font vendor.</string>
</dict></plist>
PLIST

# Ad-hoc sign AFTER all bundle edits (Apple Silicon rejects a broken signature as
# "damaged"). Real distribution needs a Developer ID + notarization.
codesign --force --deep --sign - "$APP"
codesign --verify --deep "$APP" && echo "signed OK"

echo "Built: $APP  (v$VERSION)"
