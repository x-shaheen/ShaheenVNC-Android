# Android Architecture

```text
Compose / ViewModel / DataStore
            |
 Secure WebView + allowlisted navigation
            | HTTPS / WSS
     Original KasmVNC Web Client
            |
      Unmodified KasmVNC Server
```

The Hybrid design reuses the maintained KasmVNC Web Client instead of reimplementing the protocol, encodings, clipboard, keyboard, authentication, and session semantics natively. `ServerProfile` is persisted with Preferences DataStore; secrets are deliberately not stored in profiles. URL validation permits HTTPS only in release and limits debug HTTP to emulator/local hosts.

The WebView disables file and universal file access, keeps Safe Browsing enabled, cancels SSL errors, and only allows navigation on the trusted profile origin. `ConnectionManager` provides bounded exponential retry states for UI integration. Configuration changes are handled by the activity and Compose lifecycle without changing server state; the WebView remains owned by the session composition and is disposed when the session is closed.

The server core and protocol are intentionally outside the Android module. No shell, Context, arbitrary URL loader, or JavaScript-to-native command bridge is exposed.
