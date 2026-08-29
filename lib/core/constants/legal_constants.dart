class LegalConstants {
  static const String privacyPolicy = '''
### Privacy Policy for Pocket LLM Lite

**Effective Date: August 29, 2026**

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
- **Voice Features:** Speech-to-text and text-to-speech can use platform system services whose offline/network behavior depends on the installed platform engine. Audio-file transcription uses a local Cactus Whisper model; its guided installation contacts the displayed catalog destination only after the user chooses Download now.

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

**App Version: 1.0.38**
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

**MIT License**

Copyright (c) 2026 Prashant C

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Third-party libraries, models, skills, and services remain subject to their own licenses and terms.
''';
}
