## 2025-02-18 - Unrestricted URL Scheme Launching
**Vulnerability:** The app used `launchUrl` on arbitrary links found in Markdown content (Chat, Docs) without validating the scheme. This allowed potential execution of `javascript:`, `file:`, or other dangerous schemes.
**Learning:** `flutter_markdown`'s `onTapLink` and general usage of `url_launcher` does not automatically filter dangerous schemes.
**Prevention:** Always validate `uri.scheme` against a whitelist (e.g., `http`, `https`, `mailto`) before calling `launchUrl`. Implemented reusable `UrlValidator`.
