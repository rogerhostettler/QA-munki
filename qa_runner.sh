#!/bin/bash

APP="/Applications/Google Chrome.app"

echo "===== QA TEST START ====="

# INSTALL
echo "[1] Installiere via Munki..."
sudo managedsoftwareupdate --installonly

if [ ! -d "$APP" ]; then
  echo "❌ INSTALL FEHLGESCHLAGEN"
  exit 1
fi

echo "✅ INSTALL OK"

# VERSION CHECK
VERSION=$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null)
echo "Version: $VERSION"

# APP STARTEN
echo "[2] Starte App..."
open -a "Google Chrome"
sleep 5
pkill "Google Chrome" || true

# REMOVE SETZEN
echo "[3] Setze Deinstallation..."
sudo defaults write /Library/Managed\ Installs/ManagedInstalls.plist \
managed_uninstalls -array "googlechrome"

# REMOVE
echo "[4] Entferne via Munki..."
sudo managedsoftwareupdate --removeonly

if [ -d "$APP" ]; then
  echo "❌ REMOVE FEHLGESCHLAGEN"
  exit 1
fi

echo "✅ REMOVE OK"

echo "===== QA TEST SUCCESS ====="