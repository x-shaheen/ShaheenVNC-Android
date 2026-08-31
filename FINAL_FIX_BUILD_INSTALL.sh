#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

PROJECT="$HOME/ShaheenVNC-Android"
ANDROID_DIR="$PROJECT/android"
PACKAGE="com.kasmtech.kasmvnc"
ACTIVITY="$PACKAGE/.MainActivity"
MAIN_ACTIVITY="$ANDROID_DIR/app/src/main/java/com/kasmtech/kasmvnc/MainActivity.kt"
APK_SOURCE="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
DOWNLOAD_DIR="$HOME/storage/downloads"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
APK_FINAL="$DOWNLOAD_DIR/ShaheenVNC-FINAL-$TIMESTAMP.apk"
LOG="$PROJECT/final-build-$TIMESTAMP.log"

exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo " SHAHEENVNC FINAL REPAIR / BUILD / INSTALL"
echo "============================================================"

fail() {
    echo
    echo "[FATAL] $1"
    echo "[LOG] $LOG"
    exit 1
}

trap 'fail "Script failed at line $LINENO"' ERR

echo
echo "[1/14] Checking Termux environment..."

command -v java >/dev/null 2>&1 || fail "Java is not installed"
command -v git >/dev/null 2>&1 || fail "Git is not installed"
command -v unzip >/dev/null 2>&1 || fail "unzip is not installed"

[ -d "$PROJECT" ] || fail "Project directory not found: $PROJECT"
[ -d "$ANDROID_DIR" ] || fail "Android directory not found"

cd "$PROJECT"

echo "[OK] Project: $PROJECT"
echo "[OK] Java:"
java -version 2>&1 | head -3

echo
echo "[2/14] Checking Gradle..."

[ -f "$ANDROID_DIR/gradlew" ] || fail "gradlew not found"

chmod +x "$ANDROID_DIR/gradlew"

echo
echo "[3/14] Creating stable MainActivity..."

mkdir -p "$(dirname "$MAIN_ACTIVITY")"

cat > "$MAIN_ACTIVITY" <<'KOTLIN'
package com.kasmtech.kasmvnc

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        try {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

            setContent {
                ShaheenVNCApp()
            }
        } catch (exception: Exception) {
            exception.printStackTrace()
        }
    }

    override fun onBackPressed() {
        moveTaskToBack(true)
    }
}

@Composable
private fun ShaheenVNCApp() {
    MaterialTheme {
        Surface(
            modifier = Modifier.fillMaxSize()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background)
                    .padding(24.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "ShaheenVNC",
                    style = MaterialTheme.typography.headlineMedium
                )

                Text(
                    text = "Application is running",
                    modifier = Modifier.padding(top = 16.dp)
                )

                Text(
                    text = "Runtime initialized successfully",
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        }
    }
}
KOTLIN

echo "[OK] MainActivity recreated"

echo
echo "[4/14] Verifying MainActivity..."

grep -q "class MainActivity" "$MAIN_ACTIVITY" \
    || fail "MainActivity verification failed"

grep -q "setContent" "$MAIN_ACTIVITY" \
    || fail "Compose setContent missing"

if grep -nE \
    "finishAffinity|finish\(\)|System\.exit|Process\.killProcess" \
    "$MAIN_ACTIVITY"; then
    fail "Dangerous application termination code detected"
fi

echo "[OK] MainActivity verified"

echo
echo "[5/14] Checking AndroidManifest..."

MANIFEST="$ANDROID_DIR/app/src/main/AndroidManifest.xml"

[ -f "$MANIFEST" ] || fail "AndroidManifest.xml not found"

grep -q "MainActivity" "$MANIFEST" \
    || fail "MainActivity missing from AndroidManifest"

echo "[OK] Manifest verified"

echo
echo "[6/14] Removing stale build artifacts..."

cd "$ANDROID_DIR"

./gradlew --stop >/dev/null 2>&1 || true

rm -rf .gradle
rm -rf app/build

echo "[OK] Build cache removed"

echo
echo "[7/14] Cleaning Gradle..."

./gradlew clean --no-daemon --stacktrace

echo
echo "[8/14] Building fresh Debug APK..."

./gradlew :app:assembleDebug \
    --no-daemon \
    --stacktrace \
    --warning-mode all

echo
echo "[9/14] Verifying generated APK..."

[ -f "$APK_SOURCE" ] \
    || fail "APK was not generated"

[ -s "$APK_SOURCE" ] \
    || fail "Generated APK is empty"

echo "[OK] APK generated:"
ls -lh "$APK_SOURCE"

echo
echo "[10/14] Verifying APK archive..."

unzip -t "$APK_SOURCE" >/dev/null \
    || fail "APK archive is corrupted"

echo "[OK] APK archive valid"

echo
echo "[11/14] Copying final APK..."

mkdir -p "$DOWNLOAD_DIR"

rm -f "$DOWNLOAD_DIR/ShaheenVNC-FINAL-"*.apk 2>/dev/null || true

cp -f "$APK_SOURCE" "$APK_FINAL"

chmod 644 "$APK_FINAL" || true

[ -f "$APK_FINAL" ] \
    || fail "Failed to copy final APK"

echo "[OK] Final APK:"
ls -lh "$APK_FINAL"

echo
echo "[12/14] Checking installed package through ADB..."

ADB_AVAILABLE=false

if command -v adb >/dev/null 2>&1; then
    if adb get-state >/dev/null 2>&1; then
        ADB_AVAILABLE=true
        echo "[OK] ADB device connected"
    else
        echo "[INFO] ADB exists but no authorized device connected"
    fi
else
    echo "[INFO] ADB not available"
fi

echo
echo "[13/14] Installing APK..."

if [ "$ADB_AVAILABLE" = true ]; then

    echo "[+] Removing old application..."
    adb uninstall "$PACKAGE" >/dev/null 2>&1 || true

    echo "[+] Installing fresh APK..."
    adb install "$APK_FINAL" \
        || fail "ADB installation failed"

    echo
    echo "[+] Verifying installation..."

    adb shell pm path "$PACKAGE" \
        || fail "Package installation verification failed"

    echo
    echo "[+] Starting application..."

    adb shell am force-stop "$PACKAGE" || true

    adb shell monkey \
        -p "$PACKAGE" \
        -c android.intent.category.LAUNCHER \
        1 >/dev/null

    echo "[OK] Application launch command sent"

else

    echo "[ACTION REQUIRED]"
    echo
    echo "A fresh APK has been created."
    echo "The Android installer will now be opened."
    echo
    echo "IMPORTANT:"
    echo "1. Uninstall the OLD ShaheenVNC application first."
    echo "2. Install ONLY the APK opened now."
    echo "3. Do not install ShaheenVNC-debug.apk or ShaheenVNC-test.apk."
    echo

    command -v termux-open >/dev/null 2>&1 \
        && termux-open "$APK_FINAL" \
        || true
fi

echo
echo "[14/14] Final verification..."

echo
echo "============================================================"
echo " SUCCESS"
echo "============================================================"
echo
echo "PROJECT:"
echo "$PROJECT"
echo
echo "SOURCE APK:"
echo "$APK_SOURCE"
echo
echo "FINAL APK:"
echo "$APK_FINAL"
echo
echo "BUILD LOG:"
echo "$LOG"
echo
echo "INSTALL PACKAGE:"
echo "$PACKAGE"
echo
echo "IMPORTANT:"
echo "Use ONLY the APK printed above."
echo "Do NOT use older ShaheenVNC-debug.apk files."
echo
echo "============================================================"
