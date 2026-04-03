#!/bin/bash

MANIFEST="/Library/Managed Installs/manifests/testclient"
BACKUP="$MANIFEST.backup"

echo "===== QA MULTI TEST START ====="

# Backup Manifest
sudo cp "$MANIFEST" "$BACKUP"

# Apps aus optional_installs auslesen
OPTIONAL_APPS=$(plutil -extract optional_installs xml1 -o - "$MANIFEST" | xmllint --xpath "//string/text()" -)

for MUNKI_NAME in $OPTIONAL_APPS; do
    APP_PATH="/Applications/$MUNKI_NAME.app"

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

    # Version prüfen
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

done

# Original Manifest wiederherstellen
sudo mv "$BACKUP" "$MANIFEST"

echo ""
echo "===== QA MULTI TEST DONE ====="