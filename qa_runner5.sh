#!/bin/bash

# Pfade
SOURCE_MANIFEST="/Library/Managed Installs/manifests/testclient"
TARGET_MANIFEST="/Library/Managed Installs/manifests/SelfServeManifest"
BACKUP="$TARGET_MANIFEST.backup"

echo "===== QA MULTI TEST START ====="

# Backup SelfServeManifest
if [ -f "$TARGET_MANIFEST" ]; then
    sudo cp "$TARGET_MANIFEST" "$BACKUP"
fi

# optional_installs aus Test-Manifest auslesen
OPTIONAL_APPS=$(plutil -extract optional_installs xml1 -o - "$SOURCE_MANIFEST" | xmllint --xpath "//string/text()" - 2>/dev/null)

if [ -z "$OPTIONAL_APPS" ]; then
    echo "⚠️ Keine optional_installs gefunden!"
    exit 1
fi

# ------------------------
# SelfServeManifest vorbereiten (managed_installs + managed_uninstalls)
# ------------------------
# managed_installs auf leeres Array setzen
sudo plutil -replace managed_installs -xml "<array></array>" "$TARGET_MANIFEST"

# Alle optional_apps in managed_installs einfügen
INDEX=0
for APP in $OPTIONAL_APPS; do
    sudo plutil -insert managed_installs.$INDEX -string "$APP" "$TARGET_MANIFEST" 2>/dev/null || true
    INDEX=$((INDEX+1))
done

# managed_uninstalls vorbereiten
sudo plutil -replace managed_uninstalls -xml "<array></array>" "$TARGET_MANIFEST"

echo "✅ SelfServeManifest aktualisiert mit optional_installs"

# ------------------------
# QA-Test: Install + Remove
# ------------------------
for MUNKI_NAME in $OPTIONAL_APPS; do
    APP_PATH="/Applications/$MUNKI_NAME.app"

    echo ""
    echo "=============================="
    echo "Teste: $MUNKI_NAME"
    echo "=============================="

    # INSTALL ERZWINGEN
    echo "[1] Force Install..."
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

    # REMOVE ERZWINGEN
    echo "[3] Force Remove..."
    sudo plutil -replace managed_uninstalls -xml "<array><string>$MUNKI_NAME</string></array>" "$TARGET_MANIFEST"

    # Key managed_installs nur entfernen, wenn vorhanden
    if plutil -extract managed_installs xml1 "$TARGET_MANIFEST" >/dev/null 2>&1; then
        sudo plutil -remove managed_installs "$TARGET_MANIFEST"
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
    echo "Stelle originales SelfServeManifest wieder her..."
    sudo mv "$BACKUP" "$TARGET_MANIFEST"
fi

echo ""
echo "===== QA MULTI TEST DONE ====="