class LegalConstants {
  static const String privacyPolicy = '''
### Privacy Policy for Pocket LLM Lite

**Effective Date: December 09, 2025**

Pocket LLM Lite ("we," "us," or "our") is an open-source, privacy-focused mobile application developed by Prashant Choudhary (contact: prashantc592114@gmail.com). The app is designed to run entirely offline on your local device, integrating with Ollama (via Termux) for local AI model interactions. This Privacy Policy describes our policies and procedures on the collection, use, and disclosure of your information when you use the Service and tells you about your privacy rights and how the law protects you.

We emphasize that Pocket LLM Lite is built with privacy as the core principle: **No data ever leaves your device**. All chats, models, images, and settings are stored locally using secure on-device storage (e.g., Hive for chat history). We do not collect, store, or transmit any personal information to servers, third parties, or ourselves. This policy is adapted from standard templates to reflect our offline-only nature, ensuring compliance with laws like GDPR, CCPA, and general data protection principles.

#### 1. Information We Collect
Since Pocket LLM Lite operates entirely offline and locally on your device, we do not collect any personal information from you. However, for transparency, here are the types of data handled **exclusively on your device**:

- **Chat History and Messages:** Text messages, timestamps, and any attached images (if using vision-capable models) that you input or generate during AI chats. These are stored locally in secure local Hive databases (on-device storage; encryption available via device settings) in your app's private storage directory.
  
- **Model and Settings Data:** Ollama endpoint URLs (e.g., http://localhost:11434), selected AI models, theme preferences, font sizes, and haptic feedback settings. These are stored using shared_preferences or Hive, all on-device.

- **Device Information (Local Only):** The app may access basic device permissions for functionality, such as camera/gallery for image uploads (via image_picker) or storage for saving chats. No device identifiers (e.g., IP address, advertising ID) are collected or used.

- **Image Data:** If you upload images for vision models, they are converted to base64 strings and appended to local prompts. Images are processed in-memory or via temporary files, which are deleted immediately after use. Base64 strings may be stored in chat history for thumbnail persistence, but this is optional and controlled by you.

Data is stored locally in app sandbox—no encryption by default, but protected by device security.

We do **not** collect:
- Personal identifiers like name, email, phone number, or location.
- Usage analytics, crash reports, or any telemetry data.
- Payment information (the app is free and has no in-app purchases).
- Any data from third-party services, as there are none integrated.

All data is stored locally and can be fully deleted by clearing app data or uninstalling the app.

#### 2. How We Collect Information
- **Directly from You:** Through user inputs in the app, such as typing messages, selecting models, or uploading images. This is all handled locally—no transmission occurs.
- **Automatically:** The app may generate logs or temporary files during operation (e.g., for Ollama API calls), but these are confined to your device and not shared.
- **From Third Parties:** None. The app does not integrate with any external services, APIs (beyond local Ollama), or trackers.

#### 3. How We Use Your Information
All use is limited to on-device functionality:
- To provide the core app features: Generating AI responses via local Ollama, displaying chat history, and managing settings.
- To improve user experience locally: For example, persisting chat scrolls or model selections for seamless sessions.
- No marketing, analytics, or sharing purposes, as no data is collected or transmitted.

#### 4. Sharing Your Information
We do **not** share, sell, rent, or disclose any of your information with anyone. Since everything is local:
- No third-party service providers (e.g., no cloud hosting, analytics like Google Analytics).
- No affiliates, partners, or in mergers/acquisitions (as this is an open-source project).
- Exceptions: Only if required by law (e.g., a court order), but given the local nature, this is highly unlikely. We would notify you if possible.

#### 5. Your Rights and Choices
As an offline app, you have full control over your data:
- **Access:** View all chats, settings, and models directly in the app.
- **Correction/Deletion:** Edit or delete individual chats via the History screen; clear all data in Settings > Chats & Storage > Clear All History (with confirmation).
- **Portability:** Export chats as TXT files locally via the History screen's export option.
- **Opt-Outs:** Not applicable, as there are no tracking, marketing, or data processing beyond local use.
- **Do Not Sell My Personal Information (CCPA):** We do not sell data.
- **GDPR Rights:** If applicable, you can request access/deletion via email to prashantc592114@gmail.com, though all data is already on your device.

To exercise rights, use in-app tools or contact us (see Section 10).

#### 6. Data Security
We prioritize security:
- Data is stored in secure local Hive databases (on-device storage; encryption available via device settings).
- Access controls: App data is sandboxed per Android/iOS standards.
- Images and prompts are processed in-memory to minimize exposure.
- However, no system is 100% secure—protect your device with passwords and avoid rooting/jailbreaking.
- We recommend backing up your device regularly, as we do not provide cloud backups.

#### 7. Data Retention
Data is retained indefinitely on your device until you delete it. No automatic deletion; you control retention via app settings.

#### 8. Children's Privacy
The app is not intended for children under 13 (or 16 in some jurisdictions). We do not knowingly collect data from children, and no features target them. Parents: Supervise usage.

#### 9. Changes to This Policy
We may update this Policy to reflect app changes. 

#### 10. Contact Us
For questions:
- Developer: Prashant Choudhary
- Email: prashantc592114@gmail.com
- GitHub: https://github.com/Mr-Dark-debug (developer profile)

Last Updated: December 09, 2025

---

This policy is provided for informational purposes and is not legal advice. Consult a lawyer for your specific needs.
''';

  static const String aboutApp = '''
### About Pocket LLM Lite

**App Version: 1.0.0 (Initial Release)**  
**Developed By: Prashant Choudhary (Mr-Dark-debug on GitHub)**  
**Email: prashantc592114@gmail.com**  
**Developer Profile: https://github.com/Mr-Dark-debug**  

Pocket LLM Lite is a free, open-source, privacy-first mobile application built with Flutter for Android and iOS devices. It empowers users to run AI chat conversations entirely offline on their local devices, without any data leaving the phone. By integrating with Ollama (an open-source local inference engine) via Termux, the app allows you to load and interact with large language models (LLMs) like Llama, Mistral, or vision-capable models like Llava—right in your pocket.

The app uses HTTP for local Ollama communication (localhost:11434) only—no external data sent. Safe for on-device use.

#### Our Motive and Vision
In an era where AI tools often rely on cloud servers, raising concerns about data privacy, surveillance, and internet dependency, Pocket LLM Lite was created to democratize AI access while prioritizing user control. The core motive is to provide a **100% local, offline AI companion** that respects your privacy: no tracking, no data sharing, no subscriptions. Whether you're a student experimenting with AI, a professional needing quick offline insights, or someone in a low-connectivity area, this app puts powerful AI in your hands without compromising security.

Inspired by the open-source community, the app aims to:
- Promote privacy: All chats, images, and models stay on-device.
- Encourage local AI adoption: Make it easy to use tools like Ollama on mobile via Termux.
- Foster innovation: As an open-source project, we welcome contributions to improve features like model management or UI enhancements.

The project started as a personal tool by Prashant C to explore local AI on mobile, evolving into a full-fledged app to share with the community. It's built on principles of minimalism, responsiveness, and accessibility—supporting dark/light themes, haptic feedback, and responsive layouts for all screen sizes.

#### Key Features
- **Chat Screen:** Intuitive messaging interface with model selection dropdown, image uploads for vision models, and streaming responses.
- **History Management:** View, rename, export, or delete past chats—all stored locally.
- **Settings:** Connect to Ollama endpoint, list/pull models, manage themes, storage, and more.
- **Offline-Only:** No internet required after setup; everything runs via local HTTP API.
- **Open-Source:** Full code available on GitHub for transparency and collaboration.

#### Technical Details
- Built with Flutter (cross-platform for Android/iOS).
- State Management: Riverpod with code generation.
- Local Storage: Hive for chats, shared_preferences for settings.
- Dependencies: http for Ollama API, image_picker for uploads, etc.
- Compatibility: Requires Termux and Ollama installed on-device.

#### Third-Party Licenses
- flutter_riverpod: MIT - https://pub.dev/packages/flutter_riverpod/license
- hive_flutter: Apache 2.0 - https://pub.dev/packages/hive_flutter/license
- http: BSD-3-Clause - https://pub.dev/packages/http/license
- image_picker: BSD-3-Clause - https://pub.dev/packages/image_picker/license
- intl: BSD-3-Clause - https://pub.dev/packages/intl/license
- shared_preferences: BSD-3-Clause - https://pub.dev/packages/shared_preferences/license
- path_provider: BSD-3-Clause - https://pub.dev/packages/path_provider/license
- permission_handler: MIT - https://pub.dev/packages/permission_handler/license
- go_router: BSD-3-Clause - https://pub.dev/packages/go_router/license
- google_fonts: Apache 2.0 - https://pub.dev/packages/google_fonts/license
- flutter_markdown: BSD-3-Clause - https://pub.dev/packages/flutter_markdown/license
- package_info_plus: BSD-3-Clause - https://pub.dev/packages/package_info_plus/license
- uuid: MIT - https://pub.dev/packages/uuid/license
- transparent_image: MIT - https://pub.dev/packages/transparent_image/license
- flutter_native_splash: MIT - https://pub.dev/packages/flutter_native_splash/license
- url_launcher: BSD-3-Clause - https://pub.dev/packages/url_launcher/license
- hive: Apache 2.0 - https://pub.dev/packages/hive/license
- flutter_colorpicker: MIT - https://pub.dev/packages/flutter_colorpicker/license
- share_plus: BSD-3-Clause - https://pub.dev/packages/share_plus/license
- google_mobile_ads: Apache 2.0 - https://pub.dev/packages/google_mobile_ads/license
- connectivity_plus: BSD-3-Clause - https://pub.dev/packages/connectivity_plus/license

For a complete list of dependencies and their licenses, see the licenses.txt file included with the app.

#### Community and Contributions
We encourage users to contribute via GitHub issues or pull requests. Report bugs, suggest features, or help with documentation. This app is a community-driven project—your feedback shapes its future!

#### Disclaimer
Pocket LLM Lite is provided "as-is" without warranties. It relies on third-party tools like Ollama and Termux, which you must install separately. Always verify AI outputs, as models can generate inaccurate information.

For support, open an issue on GitHub or email prashantc592114@gmail.com.

Thank you for using Pocket LLM Lite—your private AI pocket companion!
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