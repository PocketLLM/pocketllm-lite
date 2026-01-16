## 2025-02-18 - Unrestricted URL Scheme Launching
**Vulnerability:** The app used `launchUrl` on arbitrary links found in Markdown content (Chat, Docs) without validating the scheme. This allowed potential execution of `javascript:`, `file:`, or other dangerous schemes.
**Learning:** `flutter_markdown`'s `onTapLink` and general usage of `url_launcher` does not automatically filter dangerous schemes.
**Prevention:** Always validate `uri.scheme` against a whitelist (e.g., `http`, `https`, `mailto`) before calling `launchUrl`. Implemented reusable `UrlValidator`.

## 2025-02-18 - Exposed Android Signing Keystore (Reverted)
**Vulnerability:** The Android signing keystore (`upload-keystore.jks`) is committed to the repository root. This exposes the private signing key.
**Learning:** The user explicitly requested to keep the keystore and property files in the repository. Security best practices advise against this, but the user's requirement supersedes standard procedure in this context.
**Prevention:** In this specific repo, these files are intentionally tracked. Future audits should note this exception.

## 2025-02-18 - Improper Input Validation for API Endpoints
**Vulnerability:** The Ollama Base URL setting accepted any valid URI string (e.g., `file:///etc/hosts`), potentially leading to unexpected behavior or security issues if the HTTP client supports those schemes.
**Learning:** `Uri.tryParse` only checks for syntax validity, not semantic security.
**Prevention:** Always validate the `scheme` of user-provided URLs against a strict whitelist (e.g., `['http', 'https']`) for API endpoints.

## 2025-02-18 - HTTP Client Timeout Regression on Long-Running Operations
**Vulnerability:** Adding a blanket timeout (e.g., 10 seconds) to all `http.Client` operations broke `pullModel` (downloading large files) because `http.post` buffers the response body by default, waiting for the entire operation to complete before returning.
**Learning:** Security controls like timeouts must be context-aware. Blocking HTTP methods (`post`, `get`, `delete`) on large payloads or long tasks are incompatible with short timeouts.
**Prevention:** Only apply timeouts to control plane operations (e.g., connection checks, listing models). For data plane operations (e.g., downloads), either use streaming (so the timeout applies to chunks) or avoid timeouts/use very long ones.

## 2025-02-18 - Insecure Data Backup Configuration
**Vulnerability:** `android:allowBackup` was not explicitly set in `AndroidManifest.xml`, causing it to default to `true`. This allowed chat history and local settings to be extracted via `adb backup` or uploaded to Google Drive cloud backups, violating the app's "Privacy-First" and "Offline" principles.
**Learning:** By default, Android apps allow data backup. For privacy-focused or offline-only apps, this must be explicitly disabled to prevent data from leaving the device without user consent.
**Prevention:** Explicitly set `android:allowBackup="false"` and `android:fullBackupContent="false"` in `AndroidManifest.xml`.
