## 2024-05-22 - [Custom Action Buttons Accessibility]
**Learning:** In Flutter, `GestureDetector` on a custom container provides no semantic information to screen readers and no visual feedback (ripple) to users. For custom circular buttons, the pattern of wrapping a `Container` in `InkWell` (inside `Material` with `Clip.antiAlias` and `CircleBorder`) + `Semantics` provides the best experience. The text label below the button should be wrapped in `ExcludeSemantics` if the button itself carries the label, to avoid redundancy.
**Action:** When creating custom action buttons that deviate from `IconButton`, always wrap in `Material` > `InkWell` and ensure `Semantics` are applied to the touch target, excluding redundant text labels.

## 2024-05-23 - [Reactive Text Input State]
**Learning:** In Flutter `ConsumerStatefulWidget`, `TextEditingController` updates do not automatically trigger a rebuild of the widget. To create a reactive "Send" button that disables itself when input is empty, you must explicitly listen to the controller using `addListener` (in `initState`) and call `setState`. Forgetting to dispose of the controller or remove the listener can lead to memory leaks.
**Action:** Always wrap `TextEditingController` logic in `initState` (listener) and `dispose` (cleanup) when UI elements depend on text content updates.

## 2024-05-23 - Smooth Transitions on Chat Send Button
**Learning:** Users perceive "jank" or "abruptness" when buttons instantly change state (e.g., from Send Icon to Spinner). Using `AnimatedContainer` and `AnimatedSwitcher` makes the interface feel more polished and responsive, even if the underlying logic is the same.
**Action:** When implementing state-change buttons (like Send/Loading), always use `AnimatedSwitcher` for icons and `AnimatedContainer` for background colors to ensure smooth visual feedback.

## 2024-05-24 - [Decoupled Input Pre-filling]
**Learning:** Sibling widgets (like `ChatBody` and `ChatInput`) cannot share a `TextEditingController` directly. To allow UI elements in the body (like suggestion chips) to populate the input field, use a shared `StateProvider` (e.g., `draftMessageProvider`) as an event bus. The input widget listens to this provider, updates its controller, requests focus, and then resets the provider to null to handle repeated actions cleanly.
**Action:** Use a dedicated `StateProvider<String?>` to facilitate one-way "text fill" events between decoupled widgets.

## 2024-05-24 - [Interactive Status Indicators]
**Learning:** When displaying critical system status errors (like "Not Connected"), static text leaves users stranded without a path to resolution. Users instinctively want to tap the red text to fix the problem.
**Action:** Convert static error text into interactive chips/buttons that open a diagnostic dialog or settings screen, guiding the user to the solution.

## 2024-05-25 - [Chat Keyboard Behavior]
**Learning:** In chat interfaces, users expect the keyboard to dismiss naturally when they scroll back to read history. Default `ListView` behavior keeps the keyboard open, obscuring content.
**Action:** Always set `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` in chat message lists to align with native OS messaging patterns.
