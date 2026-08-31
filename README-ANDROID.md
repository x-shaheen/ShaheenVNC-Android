# KasmVNC Android Client

This directory contains an independent Kotlin/Jetpack Compose Android shell for the original KasmVNC web client. It does not modify the server, protocol, `common/`, `unix/`, or `kasmweb/`.

## Requirements

- Android Studio with JDK 17
- Android SDK 34
- Gradle supplied by Android Studio or a compatible wrapper

## Build

```bash
cd android
./gradlew assembleDebug
./gradlew assembleRelease
```

The debug APK is written to `android/app/build/outputs/apk/debug/app-debug.apk`.

## Usage

Install the APK, add a KasmVNC HTTPS URL, and connect. The server must expose its original web client and WebSocket endpoint. Production builds reject cleartext HTTP and invalid TLS certificates; self-signed certificates require an explicit, separately reviewed trust policy and are not silently accepted.

## Architecture limitation

`kasmweb` is a git submodule and is not vendored into the APK. Loading the server-provided client preserves its origin, cookies, WebSocket behavior, and future KasmVNC updates. Local assets can only be enabled after building the exact submodule and validating CORS, origin, authentication, and WSS behavior.
