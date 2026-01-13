## 2024-05-22 - Keystore Committed to Repository
**Vulnerability:** The Android release signing keystore (`upload-keystore.jks`) was committed to the repository root.
**Learning:** Standard `.gitignore` templates for Flutter often omit `*.jks` or `*.keystore` if they are not placed in the default location (`android/`), leading to accidental commits of signing keys.
**Prevention:** Explicitly added `*.jks`, `*.keystore`, and `key.properties` to `.gitignore` and removed the file from git tracking. Ensure developers check `.gitignore` before adding binary files.
