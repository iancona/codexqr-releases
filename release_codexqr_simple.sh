#!/bin/bash

# ============================================
# CodexQR Release Script - SIMPLE
# Non rifirma, usa la firma di Xcode Archive
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}==> $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }

# CONFIGURAZIONE
APP_NAME="CodexQR"
APP_PATH="$HOME/Desktop/${APP_NAME}.app"
DMG_OUTPUT="$HOME/Desktop/${APP_NAME}.dmg"
GITHUB_RELEASES="$HOME/Documents/codexqr-releases"
GITHUB_REPO="iancona/codexqr-releases"
CODESIGN_ID="4B1FD670400F72EA8770C875A3458FB73D5F2099"

# Cerca generate_appcast nel DerivedData
GENERATE_APPCAST=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "generate_appcast" -path "*/SourcePackages/*" 2>/dev/null | head -1)

# Verifica prerequisiti
print_step "Verifico prerequisiti..."
[ -d "$APP_PATH" ] || print_error "App non trovata in $APP_PATH\nEsporta l'app da Xcode: Product → Archive → Distribute App → Copy App"
command -v create-dmg >/dev/null || print_error "create-dmg non installato. Installa con: brew install create-dmg"
command -v gh >/dev/null || print_error "GitHub CLI non installato. Installa con: brew install gh"
[ -n "$GENERATE_APPCAST" ] && [ -f "$GENERATE_APPCAST" ] || print_error "generate_appcast non trovato. Builda il progetto con Sparkle prima."

print_success "Prerequisiti OK"

# Leggi versione
print_step "Leggo versione..."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")
echo "📦 Versione: $VERSION (build $BUILD)"

# Verifica firma esistente (NON ri-firmare!)
print_step "Verifico firma app..."
codesign --verify --deep --strict "$APP_PATH" || print_error "App non firmata correttamente! Usa Xcode Archive → Distribute"
print_success "Firma OK"

# Rimuovi DMG esistente
[ -f "$DMG_OUTPUT" ] && rm "$DMG_OUTPUT"

# Crea DMG
print_step "Creo DMG firmato e notarizzato..."
create-dmg \
  --volname "${APP_NAME}" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 175 190 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 425 190 \
  --codesign "$CODESIGN_ID" \
  --notarize "iyia" \
  "$DMG_OUTPUT" \
  "$APP_PATH"

print_success "DMG creato: $DMG_OUTPUT"

# Copia DMG per generate_appcast (serve il file locale)
print_step "Preparo per appcast..."
mkdir -p "$GITHUB_RELEASES"
DMG_FILENAME="${APP_NAME}.dmg"
cp "$DMG_OUTPUT" "$GITHUB_RELEASES/$DMG_FILENAME"

# Genera appcast
print_step "Genero appcast..."
cd "$GITHUB_RELEASES"
"$GENERATE_APPCAST" . --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$VERSION/"
print_success "Appcast generato"

# Rimuovi DMG dalla cartella (andrà nelle Releases)
rm "$GITHUB_RELEASES/$DMG_FILENAME"

# Commit e push appcast
print_step "Pusho appcast.xml..."
git add appcast.xml
git commit -m "Update appcast for v$VERSION" || echo "Nessuna modifica all'appcast"
git push

# Crea GitHub Release con il DMG
print_step "Creo GitHub Release..."
gh release create "v$VERSION" "$DMG_OUTPUT" \
  --repo "$GITHUB_REPO" \
  --title "CodexQR $VERSION" \
  --notes "Release $VERSION (build $BUILD)

## Download
Scarica **${APP_NAME}.dmg** qui sotto.

## Changelog
- Aggiornamenti vari
"

print_success "GitHub Release creata"

echo ""
echo "============================================"
echo -e "${GREEN}✓ Release $VERSION completata!${NC}"
echo "============================================"
echo ""
echo "🔗 Links:"
echo "   Release: https://github.com/$GITHUB_REPO/releases/tag/v$VERSION"
echo "   DMG: https://github.com/$GITHUB_REPO/releases/download/v$VERSION/${APP_NAME}.dmg"
echo "   Appcast: https://raw.githubusercontent.com/$GITHUB_REPO/main/appcast.xml"
