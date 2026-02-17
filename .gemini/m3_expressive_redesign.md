# PocketLLM Lite — Material 3 Expressive Redesign

> Comprehensive planning document covering codebase analysis, M3 Expressive research, target design system, and step-by-step refactor plan.

---

## Part 1: Current UI Architecture

### 1.1 Theme Setup

**File:** `lib/core/theme/app_theme.dart` (62 lines)

| Aspect | Current Implementation |
|---|---|
| `useMaterial3` | ✅ Enabled — `ThemeData.light(useMaterial3: true)` / `ThemeData.dark(useMaterial3: true)` |
| Color Scheme | `ColorScheme.fromSeed(seedColor: primaryColor)` with manual overrides for `primary`, `secondary`, `surface` |
| Primary Color | `#2196F3` (Material Blue) |
| Accent Color | `#FF4081` (Pink) |
| Light Surface | `Colors.white` / Background: `#F5F5F5` |
| Dark Surface | `#1E1E1E` / Background: `#121212` |
| Typography | `GoogleFonts.interTextTheme(base)` — Inter font family |
| AppBarTheme | Custom: no elevation, center title, explicit bg/fg colors |
| Component Themes | **None** — no `CardTheme`, `InputDecorationTheme`, `FloatingActionButtonThemeData`, `NavigationBarThemeData`, etc. |

**File:** `lib/core/theme/theme_provider.dart` (33 lines)

- Uses `Riverpod NotifierProvider<ThemeNotifier, ThemeMode>` 
- Persists theme choice via `StorageService` (Hive)
- Supports: `light`, `dark` (defaults to `light`; no `system` mode despite storing 'system')

### 1.2 Key Shared Widgets

| Widget | File | Responsibility |
|---|---|---|
| `UpdateDialog` | `lib/core/widgets/update_dialog.dart` (504 lines) | OTA update dialog with download progress, gradient header, pulse animation |

Only **one** shared widget exists. Most UI components are feature-local.

### 1.3 Main Screens & Layout Structure

| Route | Screen | Key Layout Details |
|---|---|---|
| `/splash` | `SplashScreen` | Simple centered logo + `CircularProgressIndicator`, 2s delay |
| `/onboarding` | `OnboardingScreen` | 2-page `PageView` with dot indicators, `FilledButton` for "Get Started" |
| `/chat` | `ChatScreen` | `Scaffold` with custom `AppBar`, `Drawer` for history, `ChatBody` + `ChatInput`, FAB for new chat |
| `/settings` | `SettingsScreen` (1867 lines) | Massive settings screen with sections: Connection, Models, Prompts, Enhancer, Usage Limits, Storage, Appearance, Updates, About. Ad banners. |
| `/settings/prompts` | `PromptManagementScreen` | CRUD for system prompts |
| `/settings/templates` | `TemplateManagementScreen` | CRUD for message templates |
| `/settings/docs` | `Docs` | Documentation viewer |
| `/settings/customization` | `CustomizationScreen` | Chat UI customization (colors, radius, opacity, font size) |
| `/settings/activity-log` | `ActivityLogScreen` | Activity log viewer |
| `/settings/statistics` | `UsageStatisticsScreen` | Usage stats with chart |
| `/settings/starred-messages` | `StarredMessagesScreen` | Starred messages list |
| `/settings/media-gallery` | `MediaGalleryScreen` | Media gallery grid |
| `/settings/tags` | `TagManagementScreen` | Tag CRUD |
| `/settings/profile` | `ProfileScreen` | User profile |

### 1.4 Chat UI Components

| Widget | File | Size | Description |
|---|---|---|---|
| `ChatBody` | `chat_body.dart` | 335 lines | Scrollable message list, empty state, streaming bubble, scroll-to-bottom FAB |
| `ChatBubble` | `chat_bubble.dart` | 844 lines | Message bubble with markdown, images, attachments, starring, editing, deletion, copy, share. Long-press focused menu overlay |
| `ChatInput` | `chat_input.dart` | 1125 lines | Text field, image/file pickers, prompt enhancer, templates, draft saving, attachment previews |
| `ThreeDotLoadingIndicator` | `three_dot_loading_indicator.dart` | 85 lines | Animated 3-dot typing indicator |
| `TemplatesSheet` | `templates_sheet.dart` | ~40 lines | Bottom sheet for quick message templates |
| `ChatSettingsDialog` | `chat_settings_dialog.dart` | Dialog for per-chat settings |
| `TagEditorDialog` | `tag_editor_dialog.dart` | Dialog for editing chat tags |
| `ChatHistoryScreen` | `chat_history_screen.dart` | 58K bytes — full history list with search, filters, archive |
| `ArchivedChatsScreen` | `archived_chats_screen.dart` | Archive view |
| `StarredMessagesScreen` | `starred_messages_screen.dart` | Starred messages view |

### 1.5 Existing Material 3 Usage

- ✅ `useMaterial3: true` on both themes
- ✅ `ColorScheme.fromSeed()` 
- ✅ `FilledButton` in onboarding
- ✅ `LinearProgressIndicator` in update dialog
- ❌ Manual color overrides breaking seed-generated harmony
- ❌ No dynamic color / platform color
- ❌ No component themes (everything styled inline)
- ❌ No M3 shapes — all `RoundedRectangleBorder` with hardcoded radii
- ❌ No M3 typography — uses `GoogleFonts.interTextTheme` without mapped roles
- ❌ No spring animations or M3 motion patterns
- ❌ No `NavigationBar`, `NavigationRail`, `SearchBar`, or M3 expressive components

---

## Part 2: M3 Expressive for Flutter — Research Summary

### 2.1 What is M3 Expressive?

Material 3 Expressive (announced May 2025) is the latest evolution of Material Design focusing on **emotional engagement**. Key pillars:

1. **Vibrant Color** — Richer, more saturated color schemes with tonal palettes
2. **Emphasized Typography** — Bolder type hierarchy with display weight 475
3. **Expanded Shape Library** — 35+ shapes (gem, flower, puffy, cookie, clover, etc.) for avatars, containers, clips
4. **Fluid Motion** — Spring-based physics system for natural, alive interactions
5. **Component Flexibility** — Updated app bars, FABs, buttons, navigation, sliders, progress indicators
6. **Content Containers** — Shapes and colors used to organize and emphasize content

### 2.2 Flutter Support Status

| Feature | Status |
|---|---|
| `useMaterial3: true` | ✅ Default since Flutter 3.16 |
| `ColorScheme.fromSeed()` | ✅ Fully supported |
| M3 Component Themes | ✅ Fully supported (AppBar, Card, FAB, NavigationBar, etc.) |
| M3 Expressive Shapes | 🟡 Via `flutter_m3shapes` package (community) |
| M3 Expressive Motion (Spring tokens) | ❌ Not natively available; must implement custom springs |
| M3 Expressive Components (updated FABs, etc.) | 🟡 Partial; standard M3 components with custom styling |

### 2.3 Packages to Use

| Package | Version | Purpose |
|---|---|---|
| `flutter_m3shapes` | `^1.0.0+2` | M3 Expressive shapes (gem, flower, puffy, etc.) for avatars, containers |
| `google_fonts` | `^6.3.3` (already used) | Typography — will continue with Inter, potentially add a display font |

### 2.4 Relevant Components for PocketLLM Chat App

| Component | M3 Expressive Treatment |
|---|---|
| **Chat Bubbles** | Tonal surface colors from `ColorScheme`, rounded shapes with varied radii, subtle entrance animations |
| **Chat Input** | `InputDecorationTheme` with filled style, rounded borders, M3 color tokens |
| **App Bar** | `MediumTopAppBar` or `LargeTopAppBar` with M3 surface tint, scroll behavior |
| **Drawer / History** | `NavigationDrawer` with M3 styling, section headers |
| **FABs** | Extended FAB for "New Chat", standard FAB for scroll-to-bottom |
| **Dialogs** | M3 `Dialog` with `DialogTheme`, proper surface color hierarchy |
| **Cards** | `Card` with `CardTheme` using M3 filled/outlined/elevated variants |
| **Settings** | `ListTile` with M3 theming, `SwitchListTile`, `SegmentedButton` for theme selection |
| **Loading Indicator** | M3 `CircularProgressIndicator` with expressive colors, custom spring dots |
| **Navigation** | Could add `NavigationBar` bottom nav for chat/history/settings if desired |
| **Avatars** | M3 expressive shapes via `flutter_m3shapes` — gem for user, flower for AI |
| **Splash** | M3 expressive shape animation with brand color |
| **Onboarding** | M3 shaped containers, vibrant gradient backgrounds |

### 2.5 Custom Widgets Needed

1. **M3 Expressive Chat Bubble** — wrapping existing logic with M3 shape/color tokens 
2. **M3 Expressive Avatar** — using `flutter_m3shapes` `M3Container`
3. **Animated Page Transitions** — custom spring-based `GoRouter` transitions
4. **M3 Loading Indicator** — enhanced three-dot with spring physics
5. **Expressive Empty State** — shaped containers with illustrative icons

---

## Part 3: Target Design System

### 3.1 Color Palette

#### Seed Color Strategy
**Primary Seed:** `#6750A4` (Material Purple) — rich, vibrant, modern AI feel
**Secondary:** Derived from seed via `ColorScheme.fromSeed()`

```dart
// Light scheme
ColorScheme.fromSeed(
  seedColor: Color(0xFF6750A4),
  brightness: Brightness.light,
)

// Dark scheme  
ColorScheme.fromSeed(
  seedColor: Color(0xFF6750A4),
  brightness: Brightness.dark,
)
```

#### Color Usage

| Role | Usage |
|---|---|
| `primary` | App bar actions, FABs, primary buttons, links |
| `primaryContainer` | User chat bubble background |
| `onPrimaryContainer` | User chat bubble text |
| `secondaryContainer` | AI chat bubble background, tags, chips |
| `onSecondaryContainer` | AI chat bubble text |
| `tertiaryContainer` | Special highlights (starred messages, enhancer) |
| `surface` | Scaffold background, cards |
| `surfaceContainerLowest` | Elevated cards, dialogs |
| `surfaceContainerLow` | Navigation drawer |
| `surfaceContainer` | App bars, input areas |
| `surfaceContainerHigh` | Highlighted sections |
| `surfaceContainerHighest` | Code blocks in chat |
| `error` / `errorContainer` | Errors, disconnection indicators |
| `outline` | Borders, dividers |
| `outlineVariant` | Subtle borders |

### 3.2 Typography

Using `GoogleFonts.interTextTheme()` as base, with emphasized styles:

```dart
TextTheme _buildExpressiveTextTheme(TextTheme base) {
  return GoogleFonts.interTextTheme(base).copyWith(
    displayLarge: GoogleFonts.inter(fontSize: 57, fontWeight: FontWeight.w500, letterSpacing: -0.25),
    displayMedium: GoogleFonts.inter(fontSize: 45, fontWeight: FontWeight.w500),
    displaySmall: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w500),
    headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w600),
    headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15),
    titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.15),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
    bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
    labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
  );
}
```

**Emphasis mappings:**
- Chat message body → `bodyLarge`
- Chat timestamp → `labelSmall`
- Chat sender name → `titleSmall` 
- App bar title → `titleLarge`
- Settings section header → `titleMedium`
- Onboarding titles → `headlineMedium`
- Dialog titles → `headlineSmall`

### 3.3 Shape System

Using `flutter_m3shapes` for decorative shapes:

| Element | Shape | Rationale |
|---|---|---|
| User Avatar | `M3Shapes.gem` | Distinctive, angular, personal |
| AI Avatar | `M3Shapes.flower` | Organic, friendly, AI-like |
| Media Gallery Thumbnails | `M3Shapes.puffy` | Soft, approachable |
| Profile Picture | `M3Shapes.circle` | Classic, clean |
| Onboarding Icons | `M3Shapes.soft_burst` | Energetic, welcoming |
| Tag Badges | `M3Shapes.pill` | Compact, readable |
| Settings Header Icons | `M3Shapes.sunny` | Warm, inviting |
| Splash Logo Container | `M3Shapes.c6_sided_cookie` | Unique, memorable |

**Standard Shapes (via Flutter):**

| Element | Border Radius |
|---|---|
| Chat bubble (user) | `BorderRadius.only(topLeft: 20, topRight: 20, bottomLeft: 20, bottomRight: 4)` |
| Chat bubble (AI) | `BorderRadius.only(topLeft: 20, topRight: 20, bottomLeft: 4, bottomRight: 20)` |
| Cards | `16.0` |
| Dialogs | `28.0` (M3 standard) |
| Input fields | `28.0` (pill-shaped) |
| Buttons | `20.0` |
| FABs | `16.0` (M3 standard) |
| Bottom sheets | `topLeft/topRight: 28.0` |

### 3.4 Motion Guidelines

#### Spring-Based Animation Principles

```dart
// Standard spring for most transitions
const SpringDescription standardSpring = SpringDescription(mass: 1.0, stiffness: 500, damping: 25);

// Expressive spring for emphasis (FAB press, dialog enter)
const SpringDescription expressiveSpring = SpringDescription(mass: 1.0, stiffness: 300, damping: 20);

// Gentle spring for subtle effects (chat bubble entrance)
const SpringDescription gentleSpring = SpringDescription(mass: 1.0, stiffness: 200, damping: 22);
```

#### Animation Durations & Curves

| Animation | Duration | Curve | Notes |
|---|---|---|---|
| Screen transitions | 400ms | `Curves.easeOutCubic` | GoRouter page transitions |
| Dialog enter | 300ms | `Curves.easeOutBack` | Slight overshoot |
| Dialog exit | 200ms | `Curves.easeIn` | Quick dismiss |
| Chat bubble entrance | 300ms | Custom spring | Scale + fade from bottom |
| FAB press feedback | 150ms | `Curves.easeOut` | Scale down/up |
| Expanding/collapsing | 350ms | `Curves.easeInOutCubicEmphasized` | Accordion sections |
| Page indicator | 300ms | `Curves.easeInOut` | Onboarding dots |
| Loading dots | 500ms | Staggered intervals | Already implemented |
| Bottom sheet | 350ms | `Curves.easeOutCubic` | Slide up |
| Scroll-to-bottom FAB | 200ms | `Curves.easeOut` | Fade + scale |

### 3.5 Component Mapping Table

| Current Widget | → M3 Expressive Replacement | Key Changes |
|---|---|---|
| Custom `AppBar` in `ChatScreen` | `SliverAppBar.medium` or themed `AppBar` | Use `ColorScheme.surface`, `surfaceTintColor`, M3 scroll behavior |
| Custom color chat bubbles | M3-toned `Container` | Use `primaryContainer`/`secondaryContainer` + user customization layered on top |
| `TextField` in `ChatInput` | `TextField` with M3 `InputDecorationTheme` | Filled style, `surfaceContainerHighest` fill, pill border radius |
| `CircularProgressIndicator` in splash | Themed `CircularProgressIndicator` + M3 shape container | Use primary color, optional shape wrapper |
| `ThreeDotLoadingIndicator` | Enhanced with spring physics, M3 colors | Use `ColorScheme.primary` dots, spring animation curves |
| `Drawer` for chat history | `NavigationDrawer` with M3 theming | Proper `NavigationDrawerDestination`, surface colors |
| `FloatingActionButton` (scroll to bottom) | M3 themed `FloatingActionButton.small` | Use `FloatingActionButtonThemeData`, appropriate shape |
| `FilledButton` in onboarding | Stays, but styled via `FilledButtonThemeData` | Consistent border radius, padding |
| `ElevatedButton` in update dialog | Stays, styled via `ElevatedButtonThemeData` | M3 color tokens |
| `Dialog` | M3 themed `Dialog` via `DialogTheme` | 28dp border radius, `surfaceContainerHigh` background |
| Settings `Card`s (inline styled) | M3 `Card.filled()` / `Card.outlined()` | Use `CardTheme`, proper elevation/surface tint |
| `ListTile` in settings | M3 themed `ListTile` | Via `ListTileThemeData` |
| `Switch` in settings | Stays, use `SwitchThemeData` | M3 default styling |
| `SegmentedButton` for theme picker | `SegmentedButton` (or introduce one) | M3 native component |
| `BottomSheet` for templates | M3 `showModalBottomSheet` | `BottomSheetThemeData` with shape |
| Onboarding page icons | M3 expressive shape containers (`M3Container.soft_burst`) | Vibrant colors from palette |
| Section headers in settings | M3 styled with `titleMedium` + `primary` color | Consistent typography |
| Empty state in chat | M3 styled with expressive shape + `surfaceContainerHighest` | Inviting design |

---

## Part 4: Step-by-Step Refactor Plan

### Step 0: Update Dependencies

**Actions:**
1. Add `flutter_m3shapes: ^1.0.0+2` to `pubspec.yaml`
2. Run `flutter pub get`
3. Verify the app still builds and runs

**Files:** `pubspec.yaml`
**Risk:** Low — adding a new package

---

### Step 1: Theme Layer (Core Foundation)

**Files to change:**
- `lib/core/theme/app_theme.dart` — **Complete rewrite**
- `lib/core/theme/theme_provider.dart` — Minor update (add `system` mode support)

**High-level changes in `app_theme.dart`:**

1. Remove hardcoded color constants (`primaryColor`, `accentColor`, `lightBackground`, etc.)
2. Use pure `ColorScheme.fromSeed()` without manual overrides
3. New seed color: `#6750A4` (vibrant purple)
4. Add comprehensive component themes:
   - `AppBarTheme` — surface color, elevation 0, scroll-under behavior
   - `CardTheme` — clipBehavior, elevation, shape with 16dp radius
   - `DialogTheme` — 28dp radius, surfaceContainerHigh
   - `InputDecorationTheme` — filled, pill-shaped, M3 colors
   - `FloatingActionButtonThemeData` — M3 shape and colors
   - `ElevatedButtonThemeData` — M3 styling
   - `FilledButtonThemeData` — M3 styling
   - `TextButtonThemeData` — M3 styling
   - `OutlinedButtonThemeData` — M3 styling
   - `IconButtonThemeData` — M3 styling
   - `BottomSheetThemeData` — top radius 28dp
   - `NavigationDrawerThemeData` — M3 colors
   - `ListTileThemeData` — M3 spacing
   - `SwitchThemeData` — M3 default
   - `SnackBarThemeData` — M3 styling
   - `ChipThemeData` — M3 styling
   - `DividerThemeData` — outlineVariant color
   - `ProgressIndicatorThemeData` — M3 colors
   - `PopupMenuThemeData` — M3 shape and colors
5. Enhanced `TextTheme` with emphasized weights for headings
6. Add page transition theme for smooth route changes

**Changes in `theme_provider.dart`:**
- Support `ThemeMode.system` as the default instead of `light`

**Risk:** Medium — all screens render differently. But since we only touch the theme, no logic changes.

---

### Step 2: Shared Widgets

**Files to change:**
- `lib/core/widgets/update_dialog.dart` — Migrate to M3 tokens

**High-level changes:**
- Replace hardcoded colors with `ColorScheme` tokens
- Use `theme.dialogTheme` shapes
- Replace manual gradient header with `primaryContainer` / `primary` colors from scheme
- Use M3 button styles instead of inline `ElevatedButton.styleFrom`
- Add entrance animation with `Curves.easeOutBack`

**New shared widgets to create:**
- `lib/core/widgets/m3_avatar.dart` — Expressive shape avatar using `flutter_m3shapes`
- `lib/core/widgets/m3_section_header.dart` — Reusable settings section header
- `lib/core/widgets/m3_empty_state.dart` — Empty state with expressive shapes

**Risk:** Low — `UpdateDialog` is self-contained

---

### Step 3: Feature Screens (One at a Time)

#### 3.1 Chat Screen

**Files:**
- `lib/features/chat/presentation/chat_screen.dart`
- `lib/features/chat/presentation/widgets/chat_body.dart`
- `lib/features/chat/presentation/widgets/chat_bubble.dart`
- `lib/features/chat/presentation/widgets/chat_input.dart`
- `lib/features/chat/presentation/widgets/three_dot_loading_indicator.dart`
- `lib/features/chat/presentation/widgets/templates_sheet.dart`
- `lib/features/chat/presentation/dialogs/chat_settings_dialog.dart`
- `lib/features/chat/presentation/dialogs/tag_editor_dialog.dart`

**Changes:**
- **ChatScreen:** Replace custom AppBar styling with theme-provided. Use `NavigationDrawer` for sidebar. Style drawer header with expressive shapes.
- **ChatBody:** Add entrance animation for new messages (scale + fade spring). Replace empty state with `M3EmptyState` widget.
- **ChatBubble:** Use `ColorScheme.primaryContainer` for user bubbles, `ColorScheme.secondaryContainer` for AI bubbles. Keep customization layer on top (user-specified colors override theme defaults if set). Use M3 shaped avatars. Replace hardcoded border radii with M3 chat bubble shapes.
- **ChatInput:** Style via `InputDecorationTheme` (already set in theme). Add subtle focus animation. Use M3 icon buttons.
- **ThreeDotLoadingIndicator:** Switch to M3 `ColorScheme.primary` dots. Consider adding spring physics but keep API identical.
- **TemplatesSheet:** Use M3 `BottomSheetThemeData` styling.
- **ChatSettingsDialog/TagEditorDialog:** Use `DialogTheme` styling.

**Risk:** High — largest and most complex screen. Chat bubble customization must be preserved.

**Mitigation:** Keep all provider/state logic untouched. Only modify the `build()` methods' visual output. Test customization settings (color picker, radius, opacity, font size) after migration.

#### 3.2 Chat History

**Files:**
- `lib/features/chat/presentation/screens/chat_history_screen.dart`
- `lib/features/chat/presentation/screens/archived_chats_screen.dart`
- `lib/features/chat/presentation/screens/starred_messages_screen.dart`

**Changes:**
- Use `M3SearchBar` or M3 styled search field
- Chat history items use `Card.filled()` with M3 shapes
- Date group headers use `titleSmall` typography
- Archive/delete actions use M3 `IconButton` styling
- Chips/tags use M3 `Chip` theming

**Risk:** Medium — large file (58K) but mostly list views

#### 3.3 Settings

**Files:**
- `lib/features/settings/settings_screen.dart` (1867 lines)
- `lib/features/settings/presentation/screens/*.dart` (6 screens)
- `lib/features/settings/presentation/widgets/*.dart` (5 dialogs)

**Changes:**
- Use `M3SectionHeader` widget for all section headers
- Replace inline-styled Cards with `Card.filled()` / `Card.outlined()`
- `ListTile` styling via theme
- Theme picker → `SegmentedButton` with icons (light/dark/system)
- Connection status → M3 styled chip/indicator
- Model cards → `Card.outlined()` with M3 shapes
- All dialogs → M3 `DialogTheme`
- Sliders → M3 `SliderThemeData`
- Switches → M3 `SwitchThemeData`

**Risk:** High — 1867-line file, many sections. But changes are purely visual.

#### 3.4 Media Gallery

**Files:**
- `lib/features/media/presentation/screens/media_gallery_screen.dart`

**Changes:**
- Image thumbnails with M3 expressive shapes (puffy clips)
- Grid cards with M3 `Card` theming
- AppBar with M3 theming

**Risk:** Low — single screen

#### 3.5 Onboarding

**Files:**
- `lib/features/onboarding/onboarding_screen.dart`
- `lib/features/onboarding/widgets/offline_notification_popup.dart`

**Changes:**
- Replace `BoxShape.circle` icon containers with M3 expressive shapes (`M3Container.soft_burst`)
- Use `ColorScheme.primaryContainer` / `tertiaryContainer` for backgrounds
- Replace hardcoded `Colors.blueAccent` / `Colors.deepPurpleAccent` with scheme colors
- Replace hardcoded `TextStyle` with theme text styles (`headlineMedium`, `bodyLarge`)
- Page indicators use `ColorScheme.primary` instead of `Theme.of(context).primaryColor` 
- `OfflineNotificationPopup` → M3 dialog styling

**Risk:** Low — simple 2-page screen

#### 3.6 Profile

**Files:**
- `lib/features/profile/presentation/screens/profile_screen.dart`
- Plus any subwidgets

**Changes:**
- Profile avatar with M3 expressive shape
- Settings-like layout using M3 cards and list tiles

**Risk:** Low

#### 3.7 Splash

**Files:**
- `lib/features/splash/splash_screen.dart`

**Changes:**
- Wrap logo in M3 expressive shape container (`M3Container.c6_sided_cookie`)
- Use `ColorScheme.primary` for progress indicator
- Add scale + fade entrance animation for logo
- Background uses `ColorScheme.surface`

**Risk:** Low — 54 lines

---

### Step 4: Motion & Animations

**Files to add/change:**
- `lib/core/theme/app_motion.dart` — **New file** with spring definitions and animation helpers
- `lib/core/router.dart` — Add custom page transitions

**Changes:**
1. Create `AppMotion` class with standard spring descriptions and common animations
2. Update `GoRouter` to use custom `CustomTransitionPage` with fade + slide transitions
3. Add entrance animations to chat bubbles (in `ChatBody`)
4. Add micro-interactions to FABs and buttons (spring scale feedback)
5. Enhance dialog entrance/exit animations
6. Add staggered item animations for list screens (history, settings)

**Risk:** Medium — animations can affect performance if overdone. Keep all animations optional/minimal and respect `MediaQuery.disableAnimations`.

---

### Summary: Risk Matrix

| Step | Risk | Mitigation |
|---|---|---|
| 0: Dependencies | 🟢 Low | Simple pub add |
| 1: Theme Layer | 🟡 Medium | All visual, no logic; test on both themes |
| 2: Shared Widgets | 🟢 Low | Self-contained |
| 3.1: Chat | 🔴 High | Preserve all providers/logic; test customization |
| 3.2: History | 🟡 Medium | Large file; list-only changes |
| 3.3: Settings | 🔴 High | 1867 lines; section-by-section migration |
| 3.4: Media | 🟢 Low | Single screen |
| 3.5: Onboarding | 🟢 Low | Simple screen |
| 3.6: Profile | 🟢 Low | Simple screen |
| 3.7: Splash | 🟢 Low | 54 lines |
| 4: Motion | 🟡 Medium | Performance-sensitive; keep subtle |

---

## Implementation Order (Recommended)

1. **Step 0** → Update deps ✅
2. **Step 1** → Theme layer (biggest visual impact, foundation for everything)
3. **Step 3.7** → Splash (simplest screen, validates theme works)
4. **Step 3.5** → Onboarding (simple, high-visibility)
5. **Step 2** → Shared widgets (reusable components ready)
6. **Step 3.1** → Chat (core experience)
7. **Step 3.2** → History
8. **Step 3.3** → Settings
9. **Step 3.4** → Media
10. **Step 3.6** → Profile
11. **Step 4** → Motion & polish

---

*Ready for implementation upon approval.*
