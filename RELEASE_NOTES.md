# Release Notes - Version 1.0.21

## **Highlights: Tavily Web Search Integration & Premium Rebranding**
This patch release introduces the highly anticipated **Tavily Web Search** integration, allowing local AI models to query the live internet in real time. We have also added a premium **Shimmering Loading Animation** (`🔍 Searching the web...`) while queries execute, and automated **Inline Markdown Citations** for returned search results. In addition, all application branding assets (splash screens, launcher icons, and documentation headers) have been updated to a sleek, modern design. Furthermore, the redundant `.github/` folder and automated release workflows have been completely removed since builds and releases are handled locally, ensuring zero overhead in CI/CD pipelines.

---

## **Feature List**

### **🔍 Tavily Web Search (New!)**
*   **Real-time Web Search (`web_search` tool)**: Native integration with the Tavily Search API directly inside our `ToolCallingService` to query live web data.
*   **Web Search Toggle**: Conveniently toggle live search on and off directly from the chat input toolbar (`Icons.language_rounded`).
*   **API Key Verification**: Built-in verification dialog guiding the user to enter their Tavily API key in settings if they attempt to search without it.
*   **Premium Shimmer Bubble**: Shows a beautiful, dynamic `🔍 Searching the web...` shimmering bubble while fetching internet resources, keeping the UI alive and responsive.
*   **Inline Source Citations**: Conditions local LLMs to cite sources via standard, clickable inline markdown links `[Source Name](URL)` that launch automatically in external browsers.
*   **Secure API Configuration**: Dedicated settings field under "Web Search (Tavily)" to easily and safely enter, preview, and persist Tavily API credentials.

### **🧩 Agent Skills System (New!)**
*   **SKILL.md Standard Format**: Follows the standard YAML frontmatter and Markdown body architecture for clean, organized, and powerful domain-specific skills.
*   **GitHub Skill Installer**: Easily download, preview, and install custom skills from any standard or raw GitHub repository URL, with automatic blob link conversion.
*   **Full CRUD & Status Toggles**: Create, read, update, and delete agent skills manually with sleek modal sheets. Easily toggle individual skills on or off using M3 switches.
*   **Smart Autocomplete Suggester**: As you type `/` in the chat input, a horizontal M3 selection panel dynamically populates matching active skills.
*   **In-Input Rich Highlights & Tap-Redirects**: Skill triggers inside the input field are highlighted in bold primary blue. Tapping on a highlighted skill word instantly redirects you to the detailed skill instructions page.
*   **Inter-Bubble Clickable Badges**: preprocessed message content converts skill triggers into interactive markdown links in both user and assistant conversation bubbles. Tapping a badge takes you directly to the skill's instructions.
*   **Dynamic LLM Skill Conditioning**: Complete automatic scanning of active skill triggers inside user queries. When a skill is detected, its markdown body is dynamically injected into the system instructions for that turn.

### **🤖 AI Chat & Interaction**
*   **Dynamic AI Personas**: Design custom AI experts with specific emoji avatars, custom system prompts, temperature overrides, and associated default local models.
*   **Horizontal Persona Picker HUD**: Choose your helper instantly when starting a chat using a gorgeous horizontally scrollable card deck with native haptic selections.
*   **Native Agentic Tools**: Toggle "Native Agentic Tools" in Chat Settings to let local models execute native code tools:
    *   **Calculator**: Solves complex and basic mathematical equations.
    *   **System Info**: Queries native platform parameter details, local dates, and local times.
    *   **Knowledge Search**: Simulates general knowledge Wikipedia-style summaries offline.
*   **Adaptive Tool UI Cards**: Beautiful custom cards rendered in the chat timeline to highlight tool calls, parameter arguments, and returning response data dynamically.
*   **DeepSeek R1 Thinking**: Streaming support for `<think>` tags, rendered in a beautifully animated Material 3 collapsible accordion.
*   **Knowledge Base RAG**: Toggle Retrieval-Augmented Generation (RAG) directly in the Chat Settings dialog to automatically query offline vector databases and augment prompts with local context.
*   **Ollama Integration**: Seamlessly connect to local Ollama instances.
*   **Model Management**: View, pull, and delete local LLM models directly from the app.
*   **Real-time Streaming**: Enjoy fast, token-by-token response streaming.
*   **Multimodal Support**: Attach images to your chats (Vision model compatible).
*   **File Attachments**: Upload text files for the AI to analyze and discuss.
*   **Chat History**: Auto-saves all your conversations locally.
*   **Markdown Support**: Full rendering of code blocks, tables, and formatted text.
*   **Prompt Enhancer**: Automatically optimize simple prompts into detailed instructions.

### **🎙️ Audio & Voice Capabilities**
*   **Offline Speech-to-Text (STT)**: Voice-type your prompts offline by holding the microphone toolbar button, sending speech directly to the text field with native pulsing animations.
*   **Offline Text-to-Speech (TTS)**: Read any AI message aloud with a single tap of the "Speak" action chip in the focused long-press menu.

### **📊 Performance Benchmarking**
*   **Speed Profiler**: Run standard scenarios (Quick Test, Complex Reasoning, Custom) to measure Time to First Token (TTFT) latency and Generation Speed (tokens/sec).
*   **Historical Logs**: Tracks past runs and shows percentage speed gains/losses compared to your device's average benchmarks.

### **🎨 Customization & Appearance**
*   **Live Preview**: See your changes instantly with a new interactive preview card.
*   **Theme Presets**: One-tap application of curated themes (Ocean Breeze, Midnight Glow, Obsidian, etc.).
*   **Granular Control**:
    *   **Colors**: Pick custom colors for User and AI bubbles using a new advanced color picker.
    *   **Typography**: Adjust font size with precise stepper controls.
    *   **Layout**: Fine-tune chat padding and bubble corner radius (Sharp, Rounded, Pill).
*   **Advanced Options**: Toggle sender avatars and set custom background colors.
*   **Haptic Feedback**: Meaningful vibrations for interactions (can be toggled).

### **🧠 System Prompt Library**
*   **Dedicated Management Page**: A screen to organize all your system prompts.
*   **CRUD Operations**: Create, Read, Update, and Delete system prompts with ease.
*   **Usage**: Select saved prompts quickly when starting new chats to define AI behavior (e.g., "Python Expert", "Creative Writer").

### **📚 Knowledge & Organization**
*   **Document Manager**: Manage ingested text, PDF, and markdown files in the local vector DB for RAG.
*   **Chat Archives**: Clean up your main list by archiving old conversations.
*   **Starred Messages**: Bookmark important messages for quick access later.
*   **Media Gallery**: Browse all images sent/received across all chats in one place.
*   **Tags**: Organize chats with custom tags for easy filtering.
*   **Full Text Search**: Search through your chat history to find specific information.

### **⚙️ Core Features**
*   **Privacy First & Ad-Free**: All monetization, Google Mobile Ads dependencies, banner widgets, and token limits are permanently removed.
*   **Offline Capable**: Works completely offline.
*   **Dark/Light Mode**: Full support for system, light, and dark themes.
*   **Export/Import**: Backup your entire chat history and settings to a JSON file.
*   **Onboarding**: Smooth introduction flow for new users.

---

## **Technical Improvements**
*   **Agentic Pipelines**: Built-in regex stream splitter and recursive follow-up loop that invokes native code handlers and re-injects tool response parameters.
*   **Performance**: Optimized stream parsing of custom tags and faster Hive read/write operations.
*   **Code Quality**: Fixed build_runner generated types, removed redundant imports, and fixed BuildContext async usage.
*   **Zero-Ad Cleanse**: Cleaned up the app settings and layout file footprints.

---

## **Release Build Command**
To build the signed, optimized release APK:
```bash
flutter build apk --split-per-abi --release
```
