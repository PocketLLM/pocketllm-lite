## 2024-05-22 - [Streaming Text Rebuilds]
**Learning:** Streaming text response token-by-token (or chunk-by-chunk) directly into the state triggers a rebuild of the entire message bubble on every update. When using `flutter_markdown`, this causes the entire Markdown document to be re-parsed and re-laid out for every single token, leading to massive UI thread jank on fast streams.
**Action:** Throttle state updates for streaming content (e.g., to 20-30 FPS) to decouple the stream processing rate from the UI render rate. This preserves responsiveness while preventing the UI thread from being overwhelmed by layout calculations.

## 2024-05-22 - [List Rendering Regex Optimization]
**Learning:** Compiling RegExp inside a list rendering loop (like `ListView.builder`) is expensive ((N)$ compilations per frame/update). Caching the compiled RegExp in the parent state reduces this to (1)$ per search query update.
**Action:** Always pre-compile RegExp for search/highlighting logic in stateful widgets and pass the compiled instance to child widgets or helper methods.
