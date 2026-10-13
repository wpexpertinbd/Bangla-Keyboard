#!/usr/bin/env bash
# Build the Linux IBus engine into linux/dist/. Reuses the shared C++ KLEngine
# from ../windows/engine (the SAME engine as macOS + Windows — byte-identical
# output). Also writes a local component XML pointing at the just-built binary so
# you can test standalone (see linux/README.md) without a system install.
#
# Needs: build-essential, pkg-config, libibus-1.0-dev  (Debian/Ubuntu:
#   sudo apt install build-essential pkg-config libibus-1.0-dev)
set -euo pipefail
cd "$(dirname "$0")"                     # linux/
ENGINE=../windows/engine                 # the shared KLEngine lives here
mkdir -p dist

# Cross-compiling (e.g. an arm64 package on an amd64 host): set CXX + PKGCONFIG to the
# target's tools — build-deb.sh does this for you (`./build-deb.sh <ver> arm64`). The
# SELF-TEST below deliberately stays native: it has to RUN here to mean anything.
CXX="${CXX:-g++}"
PKGCONFIG="${PKGCONFIG:-pkg-config}"

echo "[1/3] engine self-test (shared KLEngine on Linux, native)"
g++ -std=c++17 -O2 -I"$ENGINE" "$ENGINE/klengine_test.cpp" "$ENGINE/klengine.cpp" -o dist/kltest
dist/kltest | grep -E '^[0-9]+/[0-9]+' | sed 's/^/      /'

echo "[2/3] ibus-engine-bangla (with voice: libpulse-simple + libcurl) [$CXX]"
$CXX -std=c++17 -O2 -I"$ENGINE" $($PKGCONFIG --cflags ibus-1.0 libpulse-simple libcurl) \
    ibus-bangla.cpp "$ENGINE/klengine.cpp" \
    -o dist/ibus-engine-bangla $($PKGCONFIG --libs ibus-1.0 libpulse-simple libcurl)

echo "[3/3] local component XML (standalone test)"
cat > dist/bangla.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<component>
  <name>org.freedesktop.IBus.Bangla</name>
  <description>Bangla Keyboard (Unicode + Classic + Phonetic)</description>
  <exec>$(pwd)/dist/ibus-engine-bangla --ibus</exec>
  <version>1.3.0</version>
  <author>BiswasHost</author>
  <license>MIT</license>
  <homepage>https://github.com/wpexpertinbd/Bangla-Keyboard</homepage>
  <textdomain>ibus-bangla</textdomain>
  <engines>
    <engine>
      <name>bangla-unicode</name>
      <language>bn</language><license>MIT</license><author>BiswasHost</author><layout>us</layout>
      <longname>Unicode</longname>
      <description>Bangla (Unicode) — fixed Windows-style layout</description>
      <icon>$(pwd)/icons/bangla-unicode.png</icon>
      <rank>1</rank>
    </engine>
    <engine>
      <name>bangla-classic</name>
      <language>bn</language><license>MIT</license><author>BiswasHost</author><layout>us</layout>
      <longname>Classic</longname>
      <description>Bangla (legacy ANSI — needs a legacy ANSI Bangla font)</description>
      <icon>$(pwd)/icons/bangla-classic.png</icon>
      <rank>0</rank>
    </engine>
    <engine>
      <name>bangla-phonetic</name>
      <language>bn</language><license>MIT</license><author>BiswasHost</author><layout>us</layout>
      <longname>Phonetic</longname>
      <description>Bangla (Phonetic) — type Bangla by sound (ami → আমি)</description>
      <icon>$(pwd)/icons/bangla-phonetic.png</icon>
      <rank>0</rank>
    </engine>
  </engines>
</component>
EOF

echo "Done -> linux/dist/ (ibus-engine-bangla + bangla.xml)"
