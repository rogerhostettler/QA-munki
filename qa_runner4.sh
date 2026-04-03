#!/bin/bash

MANIFEST="/Library/Managed Installs/manifests/testclient"
BACKUP="$MANIFEST.backup"

echo "===== QA MULTI TEST START ====="

# Backup Manifest, falls vorhanden
if [ -f "$MANIFEST" ]; then
    sudo cp "$MANIFEST" "$BACKUP"
fi

# optional_installs aus Manifest auslesen
OPTIONAL_APPS=$(plutil -extract optional_installs xml1 -o - "$MANIFEST" | xmllint --xpath "//string/text()" - 2>/dev/null)

if [ -z "$OPTIONAL_APPS" ]; then
    echo "⚠️ Keine optional_installs gefunden!"
    exit 1
fi

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

    sudo plutil -replace managed_installs -xml "<array><string>$MUNKI_NAME</string></array>" "$MANIFEST"

    # Key nur entfernen, wenn er existiert
    if plutil -extract managed_uninstalls xml1 "$MANIFEST" >/dev/null 2>&1; then
        sudo plutil -remove managed_uninstalls "$MANIFEST"
    fi

    sudo managedsoftwareupdate --installonly

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

    sudo plutil -replace managed_uninstalls -xml "<array><string>$MUNKI_NAME</string></array>" "$MANIFEST"

    # Key nur entfernen, wenn er existiert
    if plutil -extract managed_installs xml1 "$MANIFEST" >/dev/null 2>&1; then
        sudo plutil -remove managed_installs "$MANIFEST"
    fi

    sudo managedsoftwareupdate

    if [ -d "$APP_PATH" ]; then
        echo "❌ REMOVE FEHLGESCHLAGEN: $MUNKI_NAME"
        continue
    fi

    echo "✅ REMOVE OK"

done

# Backup wiederherstellen
if [ -f "$BACKUP" ]; then
    echo ""
    echo "Stelle originales Manifest wieder her..."
    sudo mv "$BACKUP" "$MANIFEST"
fi

echo ""
echo "===== QA MULTI TEST DONE ====="