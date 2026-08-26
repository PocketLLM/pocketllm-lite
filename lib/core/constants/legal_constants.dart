class LegalConstants {
  static const String privacyPolicy = '''
### Privacy Policy for Pocket LLM Lite

**Effective Date: August 03, 2026**

PocketLLM Lite performs AI inference locally by default and does not include behavioral analytics, advertising trackers, or remote crash reporting. Chats remain on the device when using local inference. Configured providers and optional online actions connect to external services as described below and in the application’s Privacy & Network settings.

#### 1. Local Data Storage & Inference
- **Chat History & Personas:** All messages, prompt templates, personas, custom skills, and attached files are stored locally in sandbox Hive databases on your device.
- **Local Model Processing:** A compatible installed GGUF runs through the on-device backend. Loopback Ollama calls (`127.0.0.1` or `localhost`) remain on the Android device; a LAN or Internet endpoint sends request content to that configured host.

#### 2. Optional External Connections & User Consent
The application includes optional network capabilities, which are disabled or subject to explicit consent:
- **Automatic Update Checks:** Optional check via `api.github.com` for new APK releases. Disabled by default.
- **Hugging Face Model Discovery:** Model browsing and GGUF file downloads via `huggingface.co`. Triggered only when searching or downloading models.
- **Tavily Web Search:** Real-time search query execution via `api.tavily.com`. Sends the search query and user API key only when web search is enabled.
- **GitHub Skill Installation:** Downloading skill Markdown manifests from `raw.githubusercontent.com` upon user request.
- **Remote Ollama Endpoints:** Connecting to external or LAN-hosted Ollama servers. A prominent warning dialog requires explicit user confirmation before connecting to remote hosts.
- **OpenAI-Compatible Providers:** Sends model identifiers, prompts, relevant history, and requested attachments or embedding text to endpoints you explicitly configure.
- **External Links:** A user action can open documentation, source, release, or chat links in another application after the network policy records and allows the destination.

#### 3. Voice and Image Processing
- **Image Processing:** OCR input stays in the Android ML Kit path. Chat images are sent only to a selected model/provider whose capability is explicitly configured; remote providers receive the image content.
- **Voice Features:** Speech-to-text and text-to-speech can use platform system services whose offline/network behavior depends on the installed platform engine. Audio-file transcription uses an already-installed local Cactus Whisper model.

#### 4. Locally Stored Diagnostic Logs
- Crash reports, Flutter UI errors, and activity logs are stored locally in `error_logs` and `activity_logs` Hive boxes. No telemetry or log data is uploaded automatically.

#### 5. Data Deletion and User Retention
You retain complete control over all stored data. Clearing app history, deleting specific chats, or uninstalling the app permanently removes all local databases.

#### 6. External Domains List
When optional online features are activated, PocketLLM Lite may communicate with:
- `api.github.com` (Update checks)
- `huggingface.co` (Model discovery & binary downloads)
- `api.tavily.com` (Web search)
- `raw.githubusercontent.com` (Skill manifests)
- User-configured remote Ollama IPs/domains (Remote inference)
- User-configured OpenAI-compatible domains (Remote inference and embeddings)
- User-selected HTTP(S) destinations opened in another application

#### 7. User Controls & Strict Offline Mode
In **Settings > Privacy & Network Centre**, you can toggle **Strict Offline Mode** to block all non-loopback application-owned requests and policy-aware HTTP(S) link handoffs. Loopback is allowed. The setting is not a device firewall and cannot control another app after a confirmed handoff such as an email draft or package installation.
''';

  static const String aboutApp = '''
### About Pocket LLM Lite

**App Version: 1.0.36**
**Developed By: Prashant Choudhary (Mr-Dark-debug on GitHub)**  
**Developer Profile: https://github.com/Mr-Dark-debug**  

PocketLLM Lite is an open-source, auditable local AI workspace featuring transparent networking, local-by-default inference, private memory, document intelligence, and permission-controlled agent tools.

#### Core Principles
- **Local-First:** Compatible GGUF models can run on-device; loopback Ollama remains on the device, while configured LAN/remote providers receive the request content they need.
- **Transparent Privacy:** Detailed audit logging of every external request, Strict Offline Mode, and granular feature toggles.
- **No Trackers:** Zero advertising SDKs, analytics tracking packages, or remote crash reporting services.
''';

  static const String license = '''
### License for Pocket LLM Lite

**Pocket LLM Lite Non-Commercial Software License Agreement**

This Non-Commercial Software License Agreement (the "Agreement") is between you (the "User" or "Licensee") and Prashant C (the "Developer" or "Licensor"), the sole owner and developer of Pocket LLM Lite (the "Software"). The Software includes the source code, executable files, documentation, and any related materials. By downloading, installing, or using the Software, you agree to be bound by this Agreement. If you do not agree, do not use the Software.

#### 1. Scope
This Agreement grants a license for non-commercial, personal use only. For commercial use, you must obtain explicit written permission from the Developer at prashantc592114@gmail.com.

#### 2. License Grant
Subject to the terms herein, the Developer grants you a perpetual, free-of-charge, non-exclusive, non-transferable license to:
- Install and use the Software for personal, educational, or non-commercial evaluation purposes on your devices.
- Modify the source code for personal use and create derivative works, provided they are not distributed commercially.
- Make one archival backup copy.

#### 3. Restrictions
You may **not**:
- Use, distribute, or modify the Software for any commercial purpose (e.g., in a business, for profit, or in products/services that generate revenue) without prior written permission from the Developer.
- Sell, lease, rent, sublicense, assign, or transfer the Software or any rights under this Agreement.
- Reverse-engineer, decompile, disassemble, or attempt to derive the source code beyond what's provided in the open-source repository.
- Remove or alter any copyright, trademark, or proprietary notices.
- Use the Software in any outsourcing, service provider, or third-party access environment.
- Compete with the Developer by using the Software as a basis for a similar commercial product.

The Software is the intellectual property of Prashant C (prashantc592114@gmail.com). All rights not expressly granted are reserved.

#### 4. Proprietary Rights and Confidentiality
- **Ownership:** The Developer retains all title, ownership, and intellectual property rights in the Software, including copyrights, trademarks, and patents.
- **Confidentiality:** You agree not to disclose any confidential aspects of the Software (e.g., internal code logic) without permission. Violations may result in legal action.

#### 5. Disclaimer of Warranties
The Software is provided "AS-IS" without any warranties, express or implied, including but not limited to merchantability, fitness for a particular purpose, or non-infringement. The Developer does not guarantee error-free operation or uninterrupted use.

#### 6. Limitation of Liability
In no event shall the Developer be liable for any direct, indirect, incidental, special, or consequential damages (including lost profits) arising from the use or inability to use the Software, even if advised of such possibility. Liability is limited to \$0, as no fees are charged.

#### 7. Termination
This Agreement terminates immediately if you breach any term. Upon termination, you must cease use, delete all copies, and certify compliance if requested.

#### 8. Governing Law
This Agreement is governed by the laws of India (as the Developer's jurisdiction), without regard to conflict of laws. Disputes shall be resolved in courts located in [Developer's City, e.g., Mumbai, India].

#### 9. Other Terms
- **Entire Agreement:** This is the full agreement; no modifications except in writing signed by the Developer.
- **Severability:** Invalid provisions do not affect the rest.
- **Export Compliance:** Comply with all applicable export laws.
- **Contact for Commercial Licensing:** For commercial use, modifications, or permissions, email prashantc592114@gmail.com.

© 2025 Prashant C. All rights reserved.

---

This license ensures personal use is free, but commercial exploitation requires permission.
''';
}
