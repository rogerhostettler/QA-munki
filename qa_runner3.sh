#!/bin/bash

MANIFEST="/Library/Managed Installs/manifests/testclient"
APP_LIST=~/QA-munki/app_list.txt
BACKUP="$MANIFEST.backup"

echo "===== QA MULTI TEST START ====="

# Backup vom echten Manifest
if [ -f "$MANIFEST" ]; then
  sudo cp "$MANIFEST" "$BACKUP"
fi

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

  sudo tee "$MANIFEST" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>catalogs</key>
    <array>
        <string>online</string>
        <string>Ring1</string>
        <string>server</string>
        <string>testing</string>
    </array>

    <key>managed_installs</key>
    <array>
        <string>$MUNKI_NAME</string>
    </array>
</dict>
</plist>
EOF

  sudo managedsoftwareupdate

  if [ ! -d "$APP_PATH" ]; then
    echo "❌ INSTALL FEHLGESCHLAGEN: $MUNKI_NAME"
    continue
  fi

  echo "✅ INSTALL OK"

  # Version check
  VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null)
  echo "Version: $VERSION"

  # App starten (Smoke Test)
  APP_NAME=$(basename "$APP_PATH" .app)
  echo "[2] Starte $APP_NAME..."
  open -a "$APP_NAME"
  sleep 5
  pkill "$APP_NAME" || true

  # ------------------------
  # REMOVE ERZWINGEN
  # ------------------------
  echo "[3] Force Remove..."

  sudo tee "$MANIFEST" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>catalogs</key>
    <array>
        <string>online</string>
        <string>Ring1</string>
        <string>server</string>
        <string>testing</string>
    </array>

    <key>managed_uninstalls</key>
    <array>
        <string>$MUNKI_NAME</string>
    </array>
</dict>
</plist>
EOF

  sudo managedsoftwareupdate

  if [ -d "$APP_PATH" ]; then
    echo "❌ REMOVE FEHLGESCHLAGEN: $MUNKI_NAME"
    continue
  fi

  echo "✅ REMOVE OK"

done < "$APP_LIST"

# Original Manifest wiederherstellen
if [ -f "$BACKUP" ]; then
  echo ""
  echo "Stelle originales Manifest wieder her..."
  sudo mv "$BACKUP" "$MANIFEST"
fi

echo ""
echo "===== QA MULTI TEST DONE ====="