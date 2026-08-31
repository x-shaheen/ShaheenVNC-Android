#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

PROJECT="$HOME/ShaheenVNC-Android"
ANDROID="$PROJECT/android"
ASSETS="$ANDROID/app/src/main/assets"
MAIN="$ANDROID/app/src/main/java/com/kasmtech/kasmvnc/MainActivity.kt"
APK="$ANDROID/app/build/outputs/apk/debug/app-debug.apk"

log() {
    printf '\n\033[1;36m[+] %s\033[0m\n' "$*"
}

warn() {
    printf '\n\033[1;33m[!] %s\033[0m\n' "$*"
}

die() {
    printf '\n\033[1;31m[-] %s\033[0m\n' "$*" >&2
    exit 1
}

trap 'echo; echo "[-] Build failed at line $LINENO"; exit 1' ERR

# ------------------------------------------------------------
# 1. Validate project
# ------------------------------------------------------------

log "Checking project"

[ -d "$PROJECT" ] || die "Project directory not found: $PROJECT"
[ -d "$ANDROID" ] || die "Android directory not found: $ANDROID"
[ -f "$ANDROID/gradlew" ] || die "Gradle wrapper not found"
[ -f "$PROJECT/.gitmodules" ] || die ".gitmodules not found"

cd "$PROJECT"

# ------------------------------------------------------------
# 2. Check required commands
# ------------------------------------------------------------

log "Checking required tools"

for cmd in git node npm python; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

echo "git:    $(git --version)"
echo "node:   $(node --version)"
echo "npm:    $(npm --version)"
echo "python: $(python --version 2>&1)"

# ------------------------------------------------------------
# 3. Initialize KasmVNC web submodule
# ------------------------------------------------------------

log "Initializing git submodules"

git submodule sync --recursive
git submodule update --init --recursive

KASMWEB="$PROJECT/kasmweb"

[ -d "$KASMWEB" ] || die "kasmweb directory does not exist"

if [ ! -f "$KASMWEB/package.json" ]; then
    die "kasmweb/package.json not found. The KasmVNC web submodule was not initialized correctly."
fi

echo
echo "KasmWeb:"
echo "  path: $KASMWEB"
echo "  commit: $(git -C "$KASMWEB" rev-parse --short HEAD 2>/dev/null || echo unknown)"

# ------------------------------------------------------------
# 4. Build KasmVNC web frontend
# ------------------------------------------------------------

log "Installing KasmVNC web dependencies"

cd "$KASMWEB"

if [ -f package-lock.json ]; then
    npm ci
else
    npm install
fi

log "Building KasmVNC web frontend"

npm run build

# ------------------------------------------------------------
# 5. Locate frontend output
# ------------------------------------------------------------

log "Locating frontend build output"

DIST=""

for candidate in \
    "$KASMWEB/dist" \
    "$KASMWEB/build" \
    "$KASMWEB/out"
do
    if [ -f "$candidate/index.html" ]; then
        DIST="$candidate"
        break
    fi
done

if [ -z "$DIST" ]; then
    echo
    echo "Frontend directory contents:"
    find "$KASMWEB" \
        -maxdepth 3 \
        -type f \
        \( -name "index.html" -o -name "vnc.html" \) \
        -print \
        2>/dev/null | head -100

    die "Could not find built KasmVNC frontend containing index.html"
fi

echo "[+] Frontend output: $DIST"

# ------------------------------------------------------------
# 6. Rebuild Android assets
# ------------------------------------------------------------

log "Installing frontend into Android assets"

mkdir -p "$ASSETS"

# Never leave an old/broken frontend mixed with the new one.
find "$ASSETS" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

cp -a "$DIST"/. "$ASSETS"/

[ -f "$ASSETS/index.html" ] || die "index.html was not copied into Android assets"

ASSET_COUNT="$(find "$ASSETS" -type f | wc -l | tr -d ' ')"

echo "[+] Android asset files: $ASSET_COUNT"
echo "[+] index.html: $ASSETS/index.html"

# ------------------------------------------------------------
# 7. Validate frontend
# ------------------------------------------------------------

log "Validating frontend"

grep -q "<html" "$ASSETS/index.html" || \
    die "index.html does not appear to be a valid HTML document"

if [ "$ASSET_COUNT" -lt 5 ]; then
    warn "Very few frontend files were generated. Checking contents:"
    find "$ASSETS" -maxdepth 2 -type f -print | head -100
fi

# ------------------------------------------------------------
# 8. Backup MainActivity
# ------------------------------------------------------------

cd "$ANDROID"

if [ -f "$MAIN" ]; then
    BACKUP="$MAIN.backup.$(date +%Y%m%d_%H%M%S)"
    cp -f "$MAIN" "$BACKUP"
    echo "[+] MainActivity backup: $BACKUP"
fi

# ------------------------------------------------------------
# 9. Write a clean MainActivity
# ------------------------------------------------------------

log "Installing corrected MainActivity.kt"

cat > "$MAIN" <<'KOTLIN'
package com.kasmtech.kasmvnc

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.os.Bundle
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.webkit.WebViewAssetLoader

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG)

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    KasmVncApp()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun KasmVncApp() {

    var webView by remember {
        mutableStateOf<WebView?>(null)
    }

    var pageTitle by remember {
        mutableStateOf("ShaheenVNC")
    }

    val assetLoader = remember {
        WebViewAssetLoader.Builder()
            .addPathHandler(
                "/assets/",
                WebViewAssetLoader.AssetsPathHandler()
            )
            .build()
    }

    BackHandler(
        enabled = webView?.canGoBack() == true
    ) {
        webView?.goBack()
    }

    DisposableEffect(Unit) {
        onDispose {
            webView?.let { view ->
                runCatching {
                    view.stopLoading()
                    view.loadUrl("about:blank")
                    view.clearHistory()
                    view.removeAllViews()
                    view.destroy()
                }
            }

            webView = null
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(pageTitle)
                },
                navigationIcon = {
                    IconButton(
                        onClick = {
                            webView?.goBack()
                        },
                        enabled = webView?.canGoBack() == true
                    ) {
                        Text("‹")
                    }
                }
            )
        }
    ) {

        AndroidView(
            modifier = Modifier.fillMaxSize(),

            factory = { context ->

                WebView(context).apply {

                    layoutParams = ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )

                    settings.apply {
                        javaScriptEnabled = true
                        domStorageEnabled = true
                        databaseEnabled = true

                        allowFileAccess = false
                        allowContentAccess = false

                        javaScriptCanOpenWindowsAutomatically = false
                        setSupportMultipleWindows(false)

                        cacheMode = WebSettings.LOAD_DEFAULT

                        mediaPlaybackRequiresUserGesture = false

                        mixedContentMode =
                            WebSettings.MIXED_CONTENT_NEVER_ALLOW
                    }

                    val currentWebView = this

                    CookieManager.getInstance().apply {
                        setAcceptCookie(true)

                        setAcceptThirdPartyCookies(
                            currentWebView,
                            true
                        )
                    }

                    webChromeClient = object : WebChromeClient() {

                        override fun onReceivedTitle(
                            view: WebView?,
                            title: String?
                        ) {
                            if (!title.isNullOrBlank()) {
                                pageTitle = title
                            }
                        }
                    }

                    webViewClient = object : WebViewClient() {

                        override fun shouldOverrideUrlLoading(
                            view: WebView?,
                            request: WebResourceRequest?
                        ): Boolean {
                            return false
                        }

                        override fun shouldInterceptRequest(
                            view: WebView?,
                            request: WebResourceRequest?
                        ): android.webkit.WebResourceResponse? {

                            val url = request?.url
                                ?: return null

                            return assetLoader
                                .shouldInterceptRequest(url)
                        }

                        override fun onPageStarted(
                            view: WebView?,
                            url: String?,
                            favicon: Bitmap?
                        ) {
                            super.onPageStarted(
                                view,
                                url,
                                favicon
                            )
                        }

                        override fun onReceivedError(
                            view: WebView?,
                            request: WebResourceRequest?,
                            error: WebResourceError?
                        ) {
                            super.onReceivedError(
                                view,
                                request,
                                error
                            )
                        }
                    }

                    loadUrl(
                        "https://appassets.androidplatform.net/assets/index.html"
                    )
                }
            },

            update = { currentWebView ->
                webView = currentWebView
            }
        )
    }
}
KOTLIN

# ------------------------------------------------------------
# 10. Validate MainActivity
# ------------------------------------------------------------

log "Validating MainActivity"

grep -q 'WebViewAssetLoader.Builder' "$MAIN" || \
    die "WebViewAssetLoader configuration missing"

grep -q 'shouldInterceptRequest' "$MAIN" || \
    die "Asset interception missing"

grep -q 'assets/index.html' "$MAIN" || \
    die "index.html URL missing"

grep -q 'setAcceptThirdPartyCookies' "$MAIN" || \
    die "Cookie configuration missing"

# ------------------------------------------------------------
# 11. Check Android assets before Gradle
# ------------------------------------------------------------

log "Checking Android project"

echo
echo "MainActivity:"
grep -n -E \
    'WebViewAssetLoader|shouldInterceptRequest|setAcceptThirdPartyCookies|loadUrl' \
    "$MAIN" || true

echo
echo "Assets:"
find "$ASSETS" -maxdepth 2 -type f | head -100

# ------------------------------------------------------------
# 12. Clean old build
# ------------------------------------------------------------

log "Cleaning previous Android build"

chmod +x "$ANDROID/gradlew"

./gradlew clean --no-daemon

# ------------------------------------------------------------
# 13. Build APK
# ------------------------------------------------------------

log "Building debug APK"

BUILD_LOG="$ANDROID/build-final.log"

set +e
./gradlew :app:assembleDebug --no-daemon 2>&1 | tee "$BUILD_LOG"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [ "$BUILD_STATUS" -ne 0 ]; then
    echo
    echo "================ BUILD ERROR ================"
    grep -n -iE \
        'error:|e: |FAILURE|Exception|Caused by:' \
        "$BUILD_LOG" \
        | tail -100 || true
    echo "============================================="
    die "Gradle build failed"
fi

# ------------------------------------------------------------
# 14. Verify APK
# ------------------------------------------------------------

log "Verifying APK"

[ -f "$APK" ] || die "APK was not generated"

[ -s "$APK" ] || die "APK exists but is empty"

APK_SIZE="$(stat -c '%s' "$APK" 2>/dev/null || wc -c < "$APK")"

[ "$APK_SIZE" -gt 100000 ] || \
    die "APK is suspiciously small: $APK_SIZE bytes"

echo "[+] APK generated:"
ls -lh "$APK"

if command -v unzip >/dev/null 2>&1; then
    unzip -t "$APK" >/dev/null || \
        die "APK ZIP integrity check failed"

    echo "[+] APK ZIP integrity: OK"
fi

# ------------------------------------------------------------
# 15. Verify index.html is actually packaged
# ------------------------------------------------------------

log "Verifying frontend is inside APK"

if command -v unzip >/dev/null 2>&1; then

    if unzip -l "$APK" | grep -q 'assets/index.html'; then
        echo "[+] assets/index.html is packaged inside APK"
    else
        echo
        unzip -l "$APK" | grep -E 'assets/|index.html' | head -100 || true
        die "assets/index.html is NOT packaged inside APK"
    fi

fi

# ------------------------------------------------------------
# 16. Copy APK to Termux shared storage
# ------------------------------------------------------------

log "Preparing Android Download directory"

if [ ! -d "$HOME/storage/downloads" ]; then
    warn "Termux storage is not configured"
    echo "Run:"
    echo "termux-setup-storage"
    echo
    echo "Then run this script again."
else

    OUTPUT="$HOME/storage/downloads/ShaheenVNC-debug.apk"

    cp -f "$APK" "$OUTPUT"

    [ -f "$OUTPUT" ] || \
        die "Failed to copy APK to Downloads"

    echo
    echo "[+] APK copied to:"
    echo "$OUTPUT"

    ls -lh "$OUTPUT"
fi

# ------------------------------------------------------------
# 17. Final report
# ------------------------------------------------------------

echo
echo "============================================================"
echo "[+] SHAHEENVNC BUILD COMPLETED SUCCESSFULLY"
echo "============================================================"
echo
echo "Project:"
echo "  $PROJECT"
echo
echo "Frontend:"
echo "  $DIST"
echo
echo "Android assets:"
echo "  $ASSETS"
echo
echo "APK:"
echo "  $APK"
echo
echo "Size:"
ls -lh "$APK"
echo
echo "Download location:"
if [ -f "$HOME/storage/downloads/ShaheenVNC-debug.apk" ]; then
    echo "  $HOME/storage/downloads/ShaheenVNC-debug.apk"
else
    echo "  Not copied because Termux shared storage is unavailable."
fi
echo
echo "============================================================"
