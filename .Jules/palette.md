## 2024-05-22 - [Custom Action Buttons Accessibility]
**Learning:** In Flutter, `GestureDetector` on a custom container provides no semantic information to screen readers and no visual feedback (ripple) to users. For custom circular buttons, the pattern of wrapping a `Container` in `InkWell` (inside `Material` with `Clip.antiAlias` and `CircleBorder`) + `Semantics` provides the best experience. The text label below the button should be wrapped in `ExcludeSemantics` if the button itself carries the label, to avoid redundancy.
**Action:** When creating custom action buttons that deviate from `IconButton`, always wrap in `Material` > `InkWell` and ensure `Semantics` are applied to the touch target, excluding redundant text labels.

## 2024-05-23 - [Reactive Text Input State]
**Learning:** In Flutter `ConsumerStatefulWidget`, `TextEditingController` updates do not automatically trigger a rebuild of the widget. To create a reactive "Send" button that disables itself when input is empty, you must explicitly listen to the controller using `addListener` (in `initState`) and call `setState`. Forgetting to dispose of the controller or remove the listener can lead to memory leaks.
**Action:** Always wrap `TextEditingController` logic in `initState` (listener) and `dispose` (cleanup) when UI elements depend on text content updates.

## 2024-05-23 - Smooth Transitions on Chat Send Button
**Learning:** Users perceive "jank" or "abruptness" when buttons instantly change state (e.g., from Send Icon to Spinner). Using `AnimatedContainer` and `AnimatedSwitcher` makes the interface feel more polished and responsive, even if the underlying logic is the same.
**Action:** When implementing state-change buttons (like Send/Loading), always use `AnimatedSwitcher` for icons and `AnimatedContainer` for background colors to ensure smooth visual feedback.
