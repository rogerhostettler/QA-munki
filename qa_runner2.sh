#!/bin/bash

MANIFEST="/Library/Managed Installs/manifests/testclient"
APP_LIST=~/QA-munki/app_list.txt

echo "===== QA MULTI TEST START ====="

while IFS="|" read -r MUNKI_NAME APP_PATH
do
  echo ""
  echo "=============================="
  echo "Teste: $MUNKI_NAME"
  echo "=============================="

  # ------------------------
  # INSTALL ERZWINGEN
  # ------------------------
  echo "[1] Force Install..."

  sudo defaults write "$MANIFEST" managed_installs -array "$MUNKI_NAME"
  sudo defaults delete "$MANIFEST" managed_uninstalls 2>/dev/null || true

  sudo managedsoftwareupdate

  if [ ! -d "$APP_PATH" ]; then
    echo "❌ INSTALL FEHLGESCHLAGEN: $MUNKI_NAME"
    continue
  fi

  echo "✅ INSTALL OK"

  # Version check
  VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null)
  echo "Version: $VERSION"

  # App starten
  APP_NAME=$(basename "$APP_PATH" .app)
  echo "[2] Starte $APP_NAME..."
  open -a "$APP_NAME"
  sleep 5
  pkill "$APP_NAME" || true

  # ------------------------
  # REMOVE ERZWINGEN
  # ------------------------
  echo "[3] Force Remove..."

  sudo defaults write "$MANIFEST" managed_uninstalls -array "$MUNKI_NAME"
  sudo defaults delete "$MANIFEST" managed_installs 2>/dev/null || true

  sudo managedsoftwareupdate

  if [ -d "$APP_PATH" ]; then
    echo "❌ REMOVE FEHLGESCHLAGEN: $MUNKI_NAME"
    continue
  fi

  echo "✅ REMOVE OK"

done < "$APP_LIST"

echo ""
echo "===== QA MULTI TEST DONE ====="

sudo defaults delete "$MANIFEST"