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
