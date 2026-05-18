# Release Notes - Version 1.0.14

## **Highlights: Real-time SST Dictation & Waveform Relocation, Premium Capsule Chat Input, and Native Agentic Tools**
This release refines the voice typing experience by relocating the dynamic voice input waveform animation next to the microphone icon in the bottom toolbar. This keeps the primary message input field fully visible and active during dictation, allowing you to see your spoken words transcribed in real time! This builds on top of our premium **Capsule Chat Input Bar** and **Embedded Persona Quick-Picker**!

---

## **Feature List**

### **🤖 AI Chat & Interaction**
*   **Dynamic AI Personas (New!)**: Design custom AI experts with specific emoji avatars, custom system prompts, temperature overrides, and associated default local models.
*   **Horizontal Persona Picker HUD (New!)**: Choose your helper instantly when starting a chat using a gorgeous horizontally scrollable card deck with native haptic selections.
*   **Native Agentic Tools (New!)**: Toggle "Native Agentic Tools" in Chat Settings to let local models execute native code tools:
    *   **Calculator**: Solves complex and basic mathematical equations.
    *   **System Info**: Queries native platform parameter details, local dates, and local times.
    *   **Knowledge Search**: Simulates general knowledge Wikipedia-style summaries offline.
*   **Adaptive Tool UI Cards (New!)**: Beautiful custom cards rendered in the chat timeline to highlight tool calls, parameter arguments, and returning response data dynamically.
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
