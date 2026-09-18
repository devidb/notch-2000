#!/bin/bash
#
# Construit Notch2000.app sans passer par xcodebuild.
#
# Utile quand la licence Xcode n'a pas été acceptée sur la machine : on compile
# avec les Command Line Tools, en empruntant à Xcode son SDK et ses greffons de
# macros SwiftUI, puis on assemble et signe le bundle à la main.
#
# Usage : Scripts/build.sh [chemin/de/sortie]

set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-build/Notch2000.app}"
XCODE="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer"
SDK="$XCODE/SDKs/MacOSX.sdk"
PLUGIN="$XCODE/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib"
SWIFTC="/Library/Developer/CommandLineTools/usr/bin/swiftc"
TARGET="arm64-apple-macosx14.0"

VERSION="0.2.1"
BUILD="3"
BUNDLE_ID="app.notch2000.Notch2000"

for path in "$SDK" "$PLUGIN" "$SWIFTC"; do
  if [ ! -e "$path" ]; then
    echo "introuvable : $path" >&2
    exit 1
  fi
done

echo "Compilation…"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

# shellcheck disable=SC2046
"$SWIFTC" -O \
  -sdk "$SDK" \
  -target "$TARGET" \
  -load-plugin-library "$PLUGIN" \
  -o "$OUT/Contents/MacOS/Notch2000" \
  $(find Notch2000 -name "*.swift")

echo "Assemblage du bundle…"
sed -e "s|\$(EXECUTABLE_NAME)|Notch2000|g" \
    -e "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|$BUNDLE_ID|g" \
    -e "s|\$(PRODUCT_NAME)|Notch2000|g" \
    -e "s|\$(MARKETING_VERSION)|$VERSION|g" \
    -e "s|\$(CURRENT_PROJECT_VERSION)|$BUILD|g" \
    -e "s|\$(MACOSX_DEPLOYMENT_TARGET)|14.0|g" \
    Notch2000/Resources/Info.plist > "$OUT/Contents/Info.plist"

echo "Icône…"
# Hors Xcode, pas d'actool pour compiler le catalogue : on dépose l'icône
# telle quelle, reconnue via CFBundleIconFile.
cp Notch2000/Resources/AppIcon.icns "$OUT/Contents/Resources/"

echo "Police de marque…"
# Déclarée par `ATSApplicationFontsPath` dans Info.plist : il suffit de la
# déposer dans Resources pour que `Font.custom` la trouve.
cp Notch2000/Resources/*.ttf "$OUT/Contents/Resources/"

echo "Localisations…"
for lproj in Notch2000/Resources/*.lproj; do
  [ -d "$lproj" ] || continue
  cp -R "$lproj" "$OUT/Contents/Resources/"
done

echo "Signature…"
# Une signature ad hoc change d'empreinte à chaque compilation : le trousseau
# voit alors une application inconnue et redemande l'accès aux identifiants de
# Claude Code. Signer avec l'identité Developer ID donne une exigence stable,
# identique à celle des versions publiées, et l'autorisation survit aux rebuilds.
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY=$(security find-identity -v -p codesigning \
    | awk -F'"' '/Developer ID Application/ { print $2; exit }')
fi
if [ -z "$IDENTITY" ]; then
  echo "  aucune identité Developer ID : repli sur une signature ad hoc" >&2
  IDENTITY="-"
fi

# Runtime durci comme en production : c'est ce qu'exige la notarisation, autant
# que le build local échoue ici plutôt que sur le runner.
codesign --force --sign "$IDENTITY" \
  --options runtime \
  --entitlements Notch2000/Resources/Notch2000.entitlements \
  "$OUT" >/dev/null

echo "Prêt : $OUT"
