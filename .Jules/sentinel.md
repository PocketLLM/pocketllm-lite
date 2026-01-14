## 2025-02-18 - Unrestricted URL Scheme Launching
**Vulnerability:** The app used `launchUrl` on arbitrary links found in Markdown content (Chat, Docs) without validating the scheme. This allowed potential execution of `javascript:`, `file:`, or other dangerous schemes.
**Learning:** `flutter_markdown`'s `onTapLink` and general usage of `url_launcher` does not automatically filter dangerous schemes.
**Prevention:** Always validate `uri.scheme` against a whitelist (e.g., `http`, `https`, `mailto`) before calling `launchUrl`. Implemented reusable `UrlValidator`.

## 2025-02-18 - Exposed Android Signing Keystore
**Vulnerability:** The Android signing keystore (`upload-keystore.jks`) was committed to the repository root and not ignored by `.gitignore`. This exposes the private signing key, allowing unauthorized parties to sign malicious updates.
**Learning:** Placing sensitive files in the project root without explicit `.gitignore` rules is a common oversight. The default Flutter `.gitignore` or `android/.gitignore` may not cover root-level keystores or might be overridden if the file is already tracked.
**Prevention:** Explicitly ignore `*.jks`, `*.keystore`, and `key.properties` in the root `.gitignore`. Ensure sensitive files are never `git add`ed.
