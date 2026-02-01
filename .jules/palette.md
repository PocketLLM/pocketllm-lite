## 2024-05-23 - Explicit List Item Affordance
**Learning:** List items that trigger navigation or dialogs (like Prompt Management) can feel static without visual cues. Users may not realize they are tappable.
**Action:** Always include a trailing icon (e.g., `chevron_right`, `edit_outlined`) or action button on interactive list tiles to improve discoverability and match the app's pattern (seen in Chat History).

## 2024-05-24 - Static Image Dead-Ends
**Learning:** `Image.memory` widgets in chat bubbles are effectively "dead pixels" if they lack interactivity. Users expect to tap images to see details, especially for text-heavy screenshots.
**Action:** Wrap chat images in a `GestureDetector` that triggers a `InteractiveViewer` modal (using `Hero` for smooth transition) to provide accessible zoom/pan functionality without heavy dependencies.
