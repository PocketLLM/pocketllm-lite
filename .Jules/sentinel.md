## 2025-02-18 - Unrestricted URL Scheme Launching
**Vulnerability:** The app used `launchUrl` on arbitrary links found in Markdown content (Chat, Docs) without validating the scheme. This allowed potential execution of `javascript:`, `file:`, or other dangerous schemes.
**Learning:** `flutter_markdown`'s `onTapLink` and general usage of `url_launcher` does not automatically filter dangerous schemes.
**Prevention:** Always validate `uri.scheme` against a whitelist (e.g., `http`, `https`, `mailto`) before calling `launchUrl`. Implemented reusable `UrlValidator`.

## 2025-02-18 - Exposed Android Signing Keystore (Reverted)
**Vulnerability:** The Android signing keystore (`upload-keystore.jks`) is committed to the repository root. This exposes the private signing key.
**Learning:** The user explicitly requested to keep the keystore and property files in the repository. Security best practices advise against this, but the user's requirement supersedes standard procedure in this context.
**Prevention:** In this specific repo, these files are intentionally tracked. Future audits should note this exception.
