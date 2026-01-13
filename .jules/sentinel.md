## 2025-02-14 - Repository Cleanup: Exposed Keystore
**Vulnerability:** A Java Keystore file (`upload-keystore.jks`) was committed to the repository root. This file typically contains the private key used to sign the Android application for release.
**Learning:** Build artifacts and secrets are easily accidentally committed if not explicitly ignored in `.gitignore` from the start of the project.
**Prevention:** Added `*.jks`, `*.keystore`, and `key.properties` to `.gitignore`. Developers should check that no secret files are tracked before pushing.
