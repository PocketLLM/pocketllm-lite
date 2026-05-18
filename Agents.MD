# AGENT.md - PocketLLM Lite Development Guidelines

> This document outlines the mandatory rules, design system, and operational protocols for AI agents and developers contributing to PocketLLM Lite. All changes must adhere to these guidelines.

---

## 1. Design System & Theme Rules

### 1.1 Material 3 Expressive Foundation
- **Framework**: Material 3 (M3) is enabled by default. All UI components must align with M3 specs.
- **Seed Color**: `#6750A4` (Material Purple). Do not change this without explicit instruction.
- **Color Scheme**: Always use `ColorScheme.fromSeed()`. 
- **NO Hardcoded Colors**: 
  - ❌ `Colors.blue`, `Colors.red`, `Colors.grey`, `Color(0xFF...)`.
  - ✅ `colorScheme.primary`, `colorScheme.error`, `colorScheme.onSurfaceVariant`.
  - Exception: "About" sections or specific static illustrations if absolutely necessary, but prefer theme tokens.

### 1.2 Component Usage
- **AppBar**: Always use the custom `M3AppBar` widget located at `lib/core/widgets/m3_app_bar.dart`. Do not use the default `AppBar()` widget.
- **Avatars**: Use `M3Avatar` (`lib/core/widgets/m3_avatar.dart`) for user and AI profile images to maintain expressive shape consistency (Gem shape for users, Flower for AI).
- **Empty States**: Use `M3EmptyState` (`lib/core/widgets/m3_empty_state.dart`) for screens with no data.
- **Section Headers**: Use `M3SectionHeader` (`lib/core/widgets/m3_section_header.dart`) for settings and list grouping.

### 1.3 UI/UX Principles
- **Clean & Minimal**: Avoid visual clutter. Use whitespace effectively.
- **Professional Polish**: Elements must align properly. Icons should be standard size (usually 24dp). Touch targets must be accessible (min 48dp).
- **Input Fields**: 
  - Border radius: `28.0` (Pill-shaped).
  - Focus border: Subtle, use `primary.withOpacity(0.3)`. No solid heavy borders.
  - Min height: `48-56px` for comfortable typing.
- **Cards & Surfaces**: Use `Card.filled()` or `Card.outlined()` with M3 styling from theme. Avoid manual shadows/elevation unless specified.

### 1.4 Persona & Tool-Calling UI Rules
- **Dynamic Persona Cards**: Horizontal picker cards inside the chat list view must render a circular container with an emoji avatar, active outline highlights using `colorScheme.primary`, and dynamic temperature tags.
- **Agentic Tool Cards**: Must render as a centered, max 600px block container with a `1.2` border using `colorScheme.tertiary` for tool calls and `colorScheme.primary` for response returns. Custom parameters/returned values must be displayed inside structured monospace code blocks.

---

## 2. Coding Standards & Workflow

### 2.1 Analysis Before Action
- **READ FIRST**: Do not modify code without reading the file completely.
- **UNDERSTAND LOGIC**: Never break existing functionality (Providers, Services, state management). UI changes must not alter business logic.

### 2.2 Code Quality
- **Linting**: Run `flutter analyze` after every batch of changes. 
- **Zero Error Policy**: No errors allowed. Warnings must be justified or resolved.
- **Formatting**: Use `dart format .` to ensure consistent code style.

### 2.3 File Structure
- **Core Widgets**: Shared components go in `lib/core/widgets/`.
- **Feature Screens**: Feature-specific UI goes in `lib/features/<feature_name>/presentation/`.

### 2.4 Native Agentic Tools Pipeline
- **Registries**: All agentic math, system, or knowledge tools must be declared in [tool_calling_service.dart](lib/services/tool_calling_service.dart).
- **Inference Responding**: LLM completions check for tool call patterns (`<tool_call name="..." args="..." />`), run corresponding platform handlers, and recursively feed response context back up to a hard limit of 5 consecutive times to prevent infinite loops.

---

## 3. Versioning & Release Protocol

### 3.1 Versioning Logic (Strict Adherence)
We use a specific increment pattern for `pubspec.yaml`:
- **Patch Updates**: Increment the 3rd digit.
  - Example: `1.0.09` → `1.0.10`
- **The "100" Rule**: The patch number increments until 100.
  - Example: `1.0.99` → `1.0.100`
- **Minor Version Bump**: When the patch number hits 100, reset it to 0 and increment the minor version.
  - Example: `1.0.100` → `1.1.0`
  - Example: `1.1.100` → `1.2.0`

### 3.2 Changelog Management (`CHANGELOG.md`)
1. **Versioning Guide**: The changelog must contain a "Versioning Guide" section explaining the logic above.
2. **Entry Format**: Every change requires an entry under the current version header.
   ```markdown
   ## [1.0.12]
   ### Added
   - Description of new feature.
   
   ### Changed
   - Description of UI update.
   ```

### 3.3 Release Notes (`RELEASE_NOTES.md`)
- **Location**: Root directory.
- **Purpose**: User-facing summary of the current release capabilities.
- **Structure**:
  1. **Highlights**: Summary of major changes (e.g., "Material 3 Redesign").
  2. **Feature List**: Comprehensive list of ALL app capabilities (Chat, History, Settings, Customization, etc.).
  3. **Instructions**: Update this file for every release to reflect the current state of the app.
  4. Release command `flutter build apk --split-per-abi --release`

### 3.4 Multi-Language Localization (l10n)
- **Infrastructure**: App uses standard `flutter_localizations` code generators with `l10n.yaml`.
- **Languages**: Supported translation resources reside in `lib/l10n/` for English (`en`), Spanish (`es`), Chinese (`zh`), Japanese (`ja`), Korean (`ko`), and Hindi (`hi`).

---

## 4. Agent Operational Checklist

Before marking a task as complete, verify:
- [x] Did I read the relevant files completely?
- [x] Are all hardcoded colors replaced with theme tokens?
- [x] Did I run `flutter analyze` with zero errors?
- [x] Is the version number updated in `pubspec.yaml` following the logic?
- [x] Is `CHANGELOG.md` updated?
- [x] Is `RELEASE_NOTES.md` updated if features changed?
- [x] Is the UI clean, minimal, and professional?