# Release Notes - Version 1.0.10

## **Highlights: Material 3 Expressive Redesign & System Prompt Library**
This release brings a major visual overhaul to the application, adopting **Material 3 Expressive** design principles. We've introduced a stunning new **Chat Appearance** page with live previews, theme presets, and granular control over your chat interface. Additionally, we've launched a dedicated **System Prompt Library** for better management of your AI personas.

---

## **Feature List**

### **🤖 AI Chat & Interaction**
*   **Ollama Integration**: Seamlessly connect to local Ollama instances.
*   **Model Management**: View, pull, and delete local LLM models directly from the app.
*   **Real-time Streaming**: Enjoy fast, token-by-token response streaming.
*   **Multimodal Support**: Attach images to your chats (Vision model compatible).
*   **File Attachments**: Upload text files for the AI to analyze and discuss.
*   **Chat History**: Auto-saves all your conversations locally.
*   **Markdown Support**: Full rendering of code blocks, tables, and formatted text.
*   **Prompt Enhancer**: Automatically optimize simple prompts into detailed instructions.

### **🎨 Customization & Appearance (New!)**
*   **Live Preview**: See your changes instantly with a new interactive preview card.
*   **Theme Presets**: One-tap application of curated themes (Ocean Breeze, Midnight Glow, Obsidian, etc.).
*   **Granular Control**:
    *   **Colors**: Pick custom colors for User and AI bubbles using a new advanced color picker.
    *   **Typography**: Adjust font size with precise stepper controls.
    *   **Layout**: Fine-tune chat padding and bubble corner radius (Sharp, Rounded, Pill).
*   **Advanced Options**: Toggle sender avatars and set custom background colors.
*   **Haptic Feedback**: Meaningful vibrations for interactions (can be toggled).

### **🧠 System Prompt Library (New!)**
*   **Dedicated Management Page**: A new screen to organize all your system prompts.
*   **CRUD Operations**: Create, Read, Update, and Delete system prompts with ease.
*   **Usage**: Select saved prompts quickly when starting new chats to define AI behavior (e.g., "Python Expert", "Creative Writer").

### **📚 Knowledge & Organization**
*   **Chat Archives**: clean up your main list by archiving old conversations.
*   **Starred Messages**: Bookmark important messages for quick access later.
*   **Media Gallery**: Browse all images sent/received across all chats in one place.
*   **Tags**: Organize chats with custom tags for easy filtering.
*   **Full Text Search**: Search through your chat history to find specific information.

### **📊 Activity & Insights**
*   **Usage Statistics**: Visual charts showing daily message counts and token usage.
*   **Activity Log**: detailed history of app actions (model pulls, deletions, settings changes).
*   **Profile**: Manage your user profile details.

### **⚙️ Core Features**
*   **Privacy First**: All data is stored locally on your device using Hive.
*   **Offline Capable**: Works completely offline (requires local Ollama instance).
*   **Dark/Light Mode**: Full support for system, light, and dark themes.
*   **Export/Import**: Backup your entire chat history and settings to a JSON file.
*   **Onboarding**: Smooth introduction flow for new users.

---

## **Technical Improvements**
*   **Performance**: Optimized list rendering for long chat histories.
*   **UI Polish**: Fixed negative constraint layout issues in customization screen.
*   **Dependencies**: Updated core packages for better stability.
