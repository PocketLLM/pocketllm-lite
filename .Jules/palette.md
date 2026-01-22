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

## 2024-05-26 - [Ripple Obscured by Container]
**Learning:** `IconButton` paints its ripple on the underlying `Material` widget. If you provide a child widget (like a `Container`) with an opaque background color, it will be drawn *over* the ripple, hiding it.
**Action:** For custom buttons with background colors, avoid `IconButton(icon: Container(color: ...))`. Instead, use `Material(color: ...)` wrapping an `InkWell` to ensure the ripple is visible and the interaction feels tactile.

## 2026-01-17 - [Destructive Action Placement]
**Learning:** When adding destructive actions (like Delete) to a dialog that already contains primary actions (Cancel/Save), simply appending it creates clutter and risks accidental clicks. Using `MainAxisAlignment.spaceBetween` to isolate the destructive action on the far left (while grouping safe actions on the right) provides a clear mental model separation for the user.
**Action:** Always visually separate destructive actions from primary navigation/save actions in dialogs, preferably by using spatial grouping (left vs right alignment).

## 2024-05-27 - [Actionable Error SnackBars]
**Learning:** Transient error messages (SnackBars) that report configuration issues (like "Not Connected") are frustrating if they are dead ends. Adding a direct action button (e.g., "SETTINGS") within the SnackBar transforms a blocker into a navigation shortcut, significantly reducing user friction.
**Action:** Always include a `SnackBarAction` in error notifications that point to a resolvable configuration issue.

## 2024-05-27 - [Contextual Message Actions]
**Learning:** Users often need to delete specific messages in a chat (e.g., to remove sensitive info or clean up). Providing a "Delete" option in the long-press context menu is a standard pattern. However, because it's destructive, it must be visually distinct (red) and require confirmation.
**Action:** Add "Delete" to message context menus with a red accent color and a confirmation dialog to prevent accidental data loss.

## 2024-05-22 - [Hidden Actions in Custom Gestures]
**Learning:** Custom gestures like `onLongPress` in `GestureDetector` are invisible to screen readers unless explicitly exposed via `Semantics`.
**Action:** Always wrap `GestureDetector` with `Semantics` and provide a corresponding action (e.g., `onLongPress`) and a `hint` to aid discoverability.

## 2024-05-28 - [Accessible Overlay Buttons]
**Learning:** For small overlay buttons (like "remove image" on a thumbnail), simply making the icon small results in inaccessible touch targets (<48px). Wrapping in a larger transparent container can work but loses standard Material ink effects.
**Action:** Use `IconButton` with `padding: EdgeInsets.zero`, custom `constraints` (e.g., min 40x40), and `alignment` (e.g., `Alignment.topRight`) to create a large touch target that visually aligns a small icon to a corner without custom gesture handling.

## 2026-01-20 - [Stateless Entrance Animations]
**Learning:** You don't always need a `StatefulWidget` and `AnimationController` for simple "entrance" animations (like fading in content). `TweenAnimationBuilder` allows you to add polished micro-interactions (fade + slide) to static content with zero boilerplate and no manual disposal logic.
**Action:** Use `TweenAnimationBuilder` for simple one-off entrance animations on empty states or dialogs to delight users without complex state management.

## 2024-05-22 - [Empty States are Opportunities]
**Learning:** Users perceive empty lists as "dead ends" if they only contain text. Adding an illustration and a direct action button transforms an empty state into an invitation to explore.
**Action:** Always pair empty state text with a relevant icon/illustration and a primary call-to-action button to guide the user's next step.

## 2026-01-20 - [Polished Bottom Sheets]
**Learning:** Native-style modal bottom sheets (used for simple selections like Image Source) feel unfinished and lack affordance without a visual drag handle and context title.
**Action:** Always include a visual drag handle (small rounded container) and a clear title at the top of modal bottom sheets to indicate they are dismissible and to set context.

## 2026-01-20 - [Redundant Interactive Targets]
**Learning:** `ListTile` widgets that navigate to a detail screen often include a trailing chevron. Using an `IconButton` for this chevron creates a second, redundant focusable target and ripple effect for the same action. Using a simple `Icon` (wrapped in `Tooltip` if needed) allows the `ListTile` to handle the interaction as a single unified target.
**Action:** Replace redundant `IconButton`s in `ListTile.trailing` with decorative `Icon`s when the action is identical to `ListTile.onTap`.
