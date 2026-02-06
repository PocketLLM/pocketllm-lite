## 2024-05-23 - Unencrypted Local Storage
**Vulnerability:** Chat history and settings are stored in unencrypted Hive boxes (`chat_box`, `settings_box`) on the device filesystem.
**Learning:** Even "privacy-first" apps may default to convenient, unencrypted storage. Hive requires an explicit encryption key (usually stored in secure storage) to be secure.
**Prevention:** Always initialize local databases with encryption keys generated/retrieved from the platform's secure enclave (Keychain/Keystore) via `flutter_secure_storage`.

## 2025-02-18 - Exposed Signing Keystore
**Vulnerability:** The Android upload keystore (`upload-keystore.jks`) was committed to the repository root.
**Learning:** Keystores are often generated in the project root by default and can be easily committed if not explicitly ignored.
**Prevention:** Add `*.jks`, `*.keystore`, and `key.properties` to `.gitignore` immediately upon project creation.

## 2025-05-21 - Insecure Launch Mode
**Vulnerability:** The app used `launchUrl` without specifying `LaunchMode.externalApplication`, potentially opening malicious links in a WebView where the app's context could be exposed or phishing could occur.
**Learning:** Default launch modes vary by platform and configuration. Opening links in an external browser isolates the web content from the app's process and cookies.
**Prevention:** Always use `mode: LaunchMode.externalApplication` when launching untrusted or external URLs.

## 2025-05-23 - Missing Stream Connection Timeouts
**Vulnerability:** `http.Client.send` for streaming responses lacks a default timeout, causing indefinite hanging if the server accepts the connection but sends no headers.
**Learning:** Convenience methods like `get()` often have easier timeout patterns, but low-level `send()` (required for streaming) needs explicit `timeout()` wrapping on the Future.
**Prevention:** Always wrap the initial `send()` call of a stream in a `timeout()` to ensure connection establishment fails fast.

## 2025-05-24 - Markdown Export Injection
**Vulnerability:** User input or LLM output containing Markdown structure tokens (like `### `) could spoof conversation structure in exported files.
**Learning:** Text-based export formats that use content-accessible delimiters must sanitize content to prevent structure injection.
**Prevention:** Encapsulate untrusted content in block elements (like blockquotes `> `) or escape structural delimiters.

## 2025-05-25 - Unverified APK Updates
**Vulnerability:** In-app updates were downloaded and installed without integrity verification, allowing potential installation of tampered APKs if the connection was compromised or the asset replaced.
**Learning:** GitHub Releases usually include checksum files (e.g., `checksums.txt`). Client-side verification using these checksums provides a layer of defense against compromised binaries.
**Prevention:** Always verify cryptographic signatures or checksums (SHA-256) of downloaded executables/APKs before installation using the update installer's verification features.
