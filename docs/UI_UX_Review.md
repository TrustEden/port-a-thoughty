# Port-A-Thoughty UI/UX Expert Review
**Date:** November 9, 2025
**Reviewer Role:** UI/UX Design & Engineering Expert
**Focus Areas:** Animation Performance, User Experience, Visual Feedback, Accessibility

---

## Executive Summary

Port-A-Thoughty has a **solid visual foundation** with a cohesive Material Design 3 implementation, thoughtful glassmorphism effects, and clean information architecture. However, there are **significant opportunities** to improve performance, animation smoothness, and user delight through micro-interactions.

**Key Findings:**
- ⚠️ **Critical Performance Issues**: Unbounded ListViews will cause lag with many notes
- ⚠️ **Animation Opportunities**: Limited use of Flutter's powerful animation system
- ⚠️ **Accessibility Gaps**: Minimal semantic labels and screen reader support
- ✅ **Strong Visual Design**: Consistent theme, good use of shadows and gradients
- ✅ **Good UX Patterns**: Undo functionality, clear feedback, logical navigation

---

## 1. Critical Performance Issues

### 1.1 Unbounded ListView Rendering ⚠️ HIGH PRIORITY

**Location:** `lib/screens/queue_screen.dart:56-63`

```dart
// CURRENT (PROBLEMATIC):
...notes.map(
  (note) => _QueueNoteCard(
    note: note,
    selected: state.selectedNoteIds.contains(note.id),
    onToggle: () => state.toggleNoteSelection(note.id),
    onDelete: () => _handleDelete(context, state, note),
  ),
)
```

**Problem:** This renders ALL notes immediately, even if there are hundreds. Each note card is a complex widget with multiple layers of decoration, shadows, and animations.

**Impact:**
- App will lag significantly with 50+ notes
- Memory usage grows linearly with note count
- Scroll performance degrades
- Initial render time increases

**Recommendation:** Use `ListView.builder()` with lazy loading:

```dart
// SUGGESTED:
ListView.builder(
  itemCount: notes.length,
  itemBuilder: (context, index) {
    final note = notes[index];
    return _QueueNoteCard(
      note: note,
      selected: state.selectedNoteIds.contains(note.id),
      onToggle: () => state.toggleNoteSelection(note.id),
      onDelete: () => _handleDelete(context, state, note),
    );
  },
)
```

**Affected Files:**
- `queue_screen.dart:56` - Queue note list
- `docs_screen.dart:84` - Documents list
- `recent_note_list.dart:19` - Recent notes preview (less critical, limited to 5)

---

### 1.2 Excessive Widget Rebuilds

**Location:** `lib/state/app_state.dart:17-31`

**Problem:** The entire app rebuilds whenever `notifyListeners()` is called, even for small state changes like recording status.

```dart
// In app_state.dart
void _handleSpeechResult(String text) {
  // ... process text ...
  notifyListeners(); // Triggers full app rebuild
}
```

**Impact:**
- Recording button animation triggers rebuilds across all screens
- TextField changes cause full screen rebuilds
- Selection changes rebuild entire lists

**Recommendation:** Use `Selector` pattern for granular rebuilds:

```dart
// CURRENT:
final state = context.watch<PortaThoughtyState>();

// SUGGESTED:
Selector<PortaThoughtyState, bool>(
  selector: (_, state) => state.isRecording,
  builder: (context, isRecording, child) {
    return _RecordingButton(isRecording: isRecording);
  },
)
```

---

### 1.3 TextField Performance

**Location:** `capture_screen.dart:316-324`, `project_selector.dart:367-380`

**Problem:** TextFields rebuild entire modal sheets on every keystroke.

```dart
TextField(
  controller: _nameController,
  onChanged: (_) => setState(() {}), // Rebuilds entire sheet
)
```

**Impact:**
- Keyboard input feels sluggish with complex UIs
- Counter updates trigger full rebuilds
- Unnecessary animation recalculations

**Recommendation:** Only rebuild specific widgets:

```dart
// Separate counter into its own StatefulWidget
// Or use ValueListenableBuilder with TextEditingController
```

---

## 2. Animation Opportunities

### 2.1 Recording Button Nested Animations

**Location:** `capture_screen.dart:150-210`

**Current State:** Two nested `AnimatedContainer` widgets with sequential duration (220ms + 180ms).

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 220),
  child: Center(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      // ...
    ),
  ),
)
```

**Issues:**
- Timing feels slightly disconnected
- No custom curves for more natural motion
- Icon swap is abrupt (no fade transition)
- Missing pulse/breathing animation while recording

**Recommendations:**

1. **Add breathing pulse animation** while recording:
```dart
// Use AnimationController with repeat
AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1500),
)..repeat(reverse: true);
```

2. **Smoother icon transitions**:
```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 250),
  transitionBuilder: (child, animation) {
    return ScaleTransition(scale: animation, child: child);
  },
  child: Image.asset(
    key: ValueKey(isRecording),
    isRecording ? 'assets/stoprecording.png' : 'assets/mic.png',
  ),
)
```

3. **Custom spring curve** for more natural feel:
```dart
curve: Curves.elasticOut, // or Curves.easeOutBack
```

---

### 2.2 Missing Hero Animations

**Current State:** No Hero animations between screens or modals.

**Opportunities:**

1. **Project selector → Project management sheet**:
```dart
Hero(
  tag: 'project-${project.id}',
  child: Image.asset('assets/projectsicon.png'),
)
```

2. **Note card → Note detail** (future feature):
```dart
Hero(
  tag: 'note-${note.id}',
  child: _NoteAvatar(note: note),
)
```

3. **Document card → Preview modal**:
```dart
Hero(
  tag: 'doc-${doc.id}',
  child: Image.asset('assets/docs.png'),
)
```

**Impact:** Creates visual continuity and professional polish.

---

### 2.3 Modal Bottom Sheet Animations

**Current State:** Default Material sheet animation (slide up).

**Location:** Multiple files using `showModalBottomSheet`

**Recommendation:** Add spring physics for iOS-style feel:

```dart
showModalBottomSheet(
  context: context,
  transitionAnimationController: AnimationController(
    vsync: navigator,
    duration: const Duration(milliseconds: 400),
  )..forward(),
  builder: (context) => /* ... */,
);

// Or use custom route with spring simulation
```

---

### 2.4 List Animations

**Current State:** Cards appear/disappear instantly when notes are added/deleted.

**Recommendation:** Use `AnimatedList` for smooth insertions/removals:

```dart
// For queue_screen.dart
AnimatedList(
  key: _listKey,
  itemBuilder: (context, index, animation) {
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut)),
      ),
      child: _QueueNoteCard(note: notes[index]),
    );
  },
)
```

---

### 2.5 Image Loading

**Current State:** Most images lack `gaplessPlayback` parameter.

**Location:** Throughout codebase (quick action buttons, avatars, etc.)

**Issue:** Brief flicker when images reload during rebuilds.

**Fix:** Add to ALL Image.asset calls:
```dart
Image.asset(
  'assets/icon.png',
  gaplessPlayback: true, // Add this everywhere
)
```

**Already Fixed In:**
- ✅ `app_header.dart:38` - Mascot image
- ✅ `project_selector.dart:204` - Project icon

**Still Missing In:**
- ❌ `capture_screen.dart:195-203` - Recording button icons
- ❌ `capture_screen.dart:649-653` - Quick action icons
- ❌ `queue_screen.dart:459-466` - Trash icon
- ❌ `docs_screen.dart:513-517` - Document icon
- ❌ And many more...

---

### 2.6 Page Transitions

**Location:** `main.dart:242-246`

**Current State:**
```dart
_pageController.animateToPage(
  index,
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
)
```

**Recommendation:** Add custom page transition for more personality:

```dart
// Consider Curves.easeOutCubic or custom cubic curve
curve: const Cubic(0.4, 0.0, 0.2, 1.0), // Material motion spec
```

**Better Yet:** Custom PageView transition builder:
```dart
PageView.builder(
  controller: _pageController,
  onPageChanged: _onPageChanged,
  itemBuilder: (context, index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double value = 1.0;
        if (_pageController.position.haveDimensions) {
          value = _pageController.page! - index;
          value = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
        }
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: _screens[index],
    );
  },
)
```

---

## 3. User Experience Improvements

### 3.1 Loading States

**Current Issues:**

1. **No skeleton loaders** - Users see blank space while data loads
2. **Loading indicators lack context** - Just a spinner, no message
3. **Async operations lack feedback** - Some buttons don't show loading state

**Recommendations:**

**Add Shimmer Loading** for lists:
```dart
// During initial load in queue_screen.dart
if (state.isLoading) {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: _ShimmerNoteCard(),
  );
}
```

**File upload loading** (`capture_screen.dart:560-578`):
```dart
// CURRENT: Generic dialog
// SUGGESTED: Progress indicator with file name
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('Processing ${file.name}...'),
        Text('Analyzing with Groq AI',
          style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  ),
);
```

---

### 3.2 Haptic Feedback

**Current State:** NO haptic feedback anywhere in the app.

**Recommendation:** Add tactile feedback for key actions:

```dart
import 'package:flutter/services.dart';

// Recording button press
onPressed: () {
  HapticFeedback.mediumImpact();
  if (isRecording) {
    await state.stopRecording();
  } else {
    HapticFeedback.heavyImpact();
    await state.startRecording();
  }
}

// Note selection
onToggle: () {
  HapticFeedback.lightImpact();
  state.toggleNoteSelection(note.id);
}

// Delete action
onDelete: () {
  HapticFeedback.heavyImpact();
  _handleDelete(context, state, note);
}

// Success feedback
HapticFeedback.notificationFeedback(
  HapticFeedbackType.success
);
```

---

### 3.3 Pull-to-Refresh

**Missing Feature:** No way to manually refresh note/doc lists.

**Recommendation:** Add to queue and docs screens:

```dart
RefreshIndicator(
  onRefresh: () async {
    await state.refreshQueue();
  },
  child: ListView(
    // ... existing list
  ),
)
```

---

### 3.4 Swipe Gestures

**Opportunity:** Add swipe-to-delete for notes (common mobile pattern).

```dart
Dismissible(
  key: Key(note.id),
  direction: DismissDirection.endToStart,
  confirmDismiss: (direction) async {
    HapticFeedback.mediumImpact();
    return await _confirmDelete(context);
  },
  onDismissed: (direction) {
    HapticFeedback.heavyImpact();
    state.deleteNote(note);
  },
  background: Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    decoration: BoxDecoration(
      color: theme.colorScheme.error,
      borderRadius: BorderRadius.circular(26),
    ),
    child: const Icon(Icons.delete, color: Colors.white),
  ),
  child: _QueueNoteCard(note: note),
)
```

---

### 3.5 Empty State Improvements

**Current State:** Good empty states with mascot images.

**Enhancement:** Add animated illustrations:

```dart
// Use Lottie or Rive animations
Lottie.asset(
  'assets/animations/empty_queue.json',
  width: 200,
  height: 200,
)
```

Or simple implicit animation:
```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: 1.0),
  duration: const Duration(milliseconds: 800),
  curve: Curves.elasticOut,
  builder: (context, value, child) {
    return Transform.scale(
      scale: value,
      child: Image.asset('assets/mascot.png'),
    );
  },
)
```

---

### 3.6 Search Functionality

**Missing Feature:** No way to search notes or docs.

**Recommendation:** Add search bar in queue/docs screens:

```dart
// Animated search bar
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  width: _isSearching ? double.infinity : 56,
  child: TextField(
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search),
      hintText: _isSearching ? 'Search notes...' : null,
    ),
  ),
)
```

With animated results highlighting:
```dart
// Highlight search matches in note text
RichText(
  text: TextSpan(
    children: _highlightMatches(note.text, searchQuery),
  ),
)
```

---

## 4. Accessibility Issues

### 4.1 Semantic Labels ⚠️

**Current State:** Only 2 tooltips in entire codebase:
- `queue_screen.dart:457` - "Remove from queue"
- `recent_note_list.dart:289` - "Note options"

**Missing:**
- Screen reader labels for images
- Semantic hints for gestures
- Live region announcements for state changes
- Focus order optimization

**Recommendations:**

```dart
// Add to all interactive elements
Semantics(
  label: 'Start voice recording',
  hint: 'Tap to record your thoughts',
  button: true,
  child: _RecordingButton(),
)

// For images
Semantics(
  label: 'Project icon',
  excludeSemantics: true, // If decorative
  child: Image.asset('assets/projectsicon.png'),
)

// Live regions for dynamic content
Semantics(
  liveRegion: true,
  child: Text('${selectedCount} notes selected'),
)

// Custom semantic actions
Semantics(
  customSemanticsActions: {
    CustomSemanticsAction(label: 'Delete note'): () {
      _handleDelete(context, state, note);
    },
  },
  child: _NoteCard(),
)
```

---

### 4.2 Animation Accessibility

**Issue:** Animations ignore system accessibility settings.

**Fix:** Respect `disableAnimations` preference:

```dart
// In animations
final animations = MediaQuery.disableAnimationsOf(context);
AnimatedContainer(
  duration: animations
    ? Duration.zero
    : const Duration(milliseconds: 200),
  // ...
)
```

---

### 4.3 Touch Targets

**Current State:** Most touch targets are adequate.

**Issue:** IconButton for settings might be small on some devices.

**Recommendation:** Ensure minimum 48x48 logical pixels:

```dart
// In project_selector.dart:186
Container(
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  child: IconButton(/* ... */),
)
```

---

## 5. Visual Polish Suggestions

### 5.1 Micro-Interactions

**Add subtle feedback animations:**

1. **Button press states** - Scale down slightly on press:
```dart
GestureDetector(
  onTapDown: (_) => setState(() => _pressed = true),
  onTapUp: (_) => setState(() => _pressed = false),
  onTapCancel: () => setState(() => _pressed = false),
  child: AnimatedScale(
    scale: _pressed ? 0.95 : 1.0,
    duration: const Duration(milliseconds: 100),
    child: /* button */,
  ),
)
```

2. **Selection feedback** - Bounce animation:
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  curve: Curves.elasticOut,
  transform: selected
    ? Matrix4.identity().scaled(1.02)
    : Matrix4.identity(),
  // ...
)
```

3. **Checkbox animations** - Custom transition:
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  decoration: BoxDecoration(
    color: selected ? theme.colorScheme.primary : Colors.transparent,
    borderRadius: BorderRadius.circular(4),
    border: Border.all(
      color: selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outline,
    ),
  ),
)
```

---

### 5.2 Card Interactions

**Current:** Cards have basic InkWell ripple.

**Enhancement:** Add elevation change on hover/press:

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  decoration: BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: const Color(0x12014F8E),
        blurRadius: _isHovered ? 34 : 24,
        offset: Offset(0, _isHovered ? 18 : 14),
      ),
    ],
  ),
)
```

---

### 5.3 Color Transitions

**Opportunity:** Animate color changes for project switches:

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 400),
  curve: Curves.easeInOut,
  decoration: BoxDecoration(
    color: project.color.withValues(alpha: 0.12),
  ),
)
```

---

### 5.4 Text Reveal Animations

**For summary bullets in docs:**

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: 1.0),
  duration: Duration(milliseconds: 300 + (index * 100)),
  builder: (context, value, child) {
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: child,
      ),
    );
  },
  child: Text(line),
)
```

---

## 6. Navigation Flow

### 6.1 Bottom Navigation Bar

**Current State:** Works well, but could be enhanced.

**Suggestions:**

1. **Active indicator animation:**
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOutCubic,
  // Custom indicator shape/position
)
```

2. **Icon scale on selection:**
```dart
AnimatedScale(
  scale: _index == index ? 1.1 : 1.0,
  duration: const Duration(milliseconds: 200),
  child: icon,
)
```

---

### 6.2 Deep Link Transitions

**Location:** `main.dart:79-114`

**Current:** Works but has 350ms delay before action.

**Recommendation:** Add loading overlay during delay:

```dart
// Show subtle loading indicator
showDialog(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  builder: (context) => const Center(
    child: CircularProgressIndicator(),
  ),
);

// Navigate and start recording
_onDestinationSelected(1);
await Future.delayed(const Duration(milliseconds: 100));
Navigator.pop(context); // Remove loading
state.startRecording();
```

---

## 7. Theme & Styling

### 7.1 Consistent Spacing

**Good:** Generally consistent spacing with multiples of 4/8.

**Opportunity:** Create spacing constants:

```dart
// Add to app_theme.dart
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
```

---

### 7.2 Animation Duration Constants

**Current:** Magic numbers scattered throughout (200ms, 220ms, 180ms, etc.).

**Recommendation:** Centralize in theme:

```dart
class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}
```

---

### 7.3 Shadow Consistency

**Current:** Multiple shadow definitions with similar values.

**Opportunity:** Reuse theme shadow:

```dart
// In app_theme.dart - already defined!
static const BoxShadow cardShadow = BoxShadow(
  color: Color(0x1A014F8E),
  blurRadius: 30,
  spreadRadius: 0,
  offset: Offset(0, 18),
);

// Use throughout app instead of defining inline
```

---

## 8. Platform-Specific Considerations

### 8.1 iOS Feel on iOS

**Opportunity:** Detect platform and adjust:

```dart
import 'dart:io';

// In modals
showCupertinoModalPopup(...) // on iOS
showModalBottomSheet(...) // on Android

// In buttons
CupertinoButton(...) // on iOS
FilledButton(...) // on Android
```

---

### 8.2 Android Material You

**Current:** Good Material 3 implementation.

**Enhancement:** Support dynamic color:

```dart
ColorScheme.fromSeed(
  seedColor: primaryBlue,
  dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
)
```

---

## 9. Recommended Implementation Priority

### Phase 1: Critical Performance (Week 1)
1. ✅ Replace unbounded ListViews with ListView.builder
2. ✅ Add gaplessPlayback to all images
3. ✅ Implement Selector pattern for recording button
4. ✅ Fix TextField rebuilds

**Impact:** Prevents performance degradation as data grows.

---

### Phase 2: Core Animations (Week 2)
1. ✅ Add Hero animations for key transitions
2. ✅ Improve recording button animation (pulse, smooth transitions)
3. ✅ Implement AnimatedList for note additions/removals
4. ✅ Add spring physics to modals

**Impact:** Makes app feel more polished and professional.

---

### Phase 3: User Delight (Week 3)
1. ✅ Add haptic feedback throughout
2. ✅ Implement swipe-to-delete
3. ✅ Add pull-to-refresh
4. ✅ Create shimmer loading states
5. ✅ Add micro-interactions (button press feedback)

**Impact:** Significantly improves perceived quality and user satisfaction.

---

### Phase 4: Accessibility (Week 4)
1. ✅ Add semantic labels to all interactive elements
2. ✅ Implement animation preferences respect
3. ✅ Ensure touch target sizes
4. ✅ Add screen reader announcements

**Impact:** Makes app usable for all users, improves App Store rating.

---

### Phase 5: Polish (Week 5)
1. ✅ Implement search functionality
2. ✅ Add animated empty states
3. ✅ Platform-specific adjustments
4. ✅ Custom page transitions
5. ✅ Text reveal animations

**Impact:** Premium feel, sets app apart from competitors.

---

## 10. Code Quality Observations

### Strengths ✅
- Clean widget composition
- Good separation of concerns (screens, widgets, services, models)
- Consistent naming conventions
- Proper use of const constructors
- Good widget extraction (readable, maintainable)

### Improvement Areas 📝
- Extract magic numbers to constants
- Add widget documentation comments
- Consider widget testing for complex animations
- Add performance monitoring (DevTools Timeline)

---

## 11. Inspiration & Examples

### Apps with Excellent Animations
- **Google Keep** - Card animations, color transitions
- **Things 3** - Subtle micro-interactions, haptic feedback
- **Notion** - Page transitions, loading states
- **Telegram** - Smooth scrolling, message animations

### Flutter Animation Packages to Consider
- `flutter_animate` - Declarative animations
- `shimmer` - Loading skeletons
- `lottie` - Complex vector animations
- `spring` - Physics-based animations
- `flutter_staggered_animations` - List entrance animations

---

## 12. Testing Recommendations

### Performance Testing
```dart
// Add to widget tests
testWidgets('Queue screen performs well with 100+ notes', (tester) async {
  final notes = List.generate(100, (i) => Note(...));

  await tester.pumpWidget(/* app with notes */);

  // Measure frame rendering time
  await tester.pumpAndSettle();

  // Scroll and measure
  await tester.drag(find.byType(ListView), const Offset(0, -500));
  await tester.pumpAndSettle();

  // Should complete without jank
});
```

### Animation Testing
```dart
testWidgets('Recording button animates smoothly', (tester) async {
  await tester.pumpWidget(/* app */);

  final button = find.byType(_RecordingButton);
  await tester.tap(button);

  // Verify animation runs
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));

  // Check visual properties changed
});
```

---

## Conclusion

Port-A-Thoughty has a **strong foundation** with clean code architecture and cohesive visual design. The most critical improvements are:

1. **Performance** - ListView.builder implementation (prevents future issues)
2. **Animations** - Hero transitions and recording button polish (professional feel)
3. **Feedback** - Haptic feedback and micro-interactions (user delight)
4. **Accessibility** - Semantic labels and screen reader support (inclusive design)

By implementing these recommendations in phases, the app will transform from "good" to "exceptional" with smooth, delightful interactions that users will love.

---

## Quick Wins (Can Implement Today)

1. Add `gaplessPlayback: true` to all images (10 minutes)
2. Add `HapticFeedback` to recording button (5 minutes)
3. Change recording button curve to `Curves.elasticOut` (2 minutes)
4. Add tooltips to all IconButtons (20 minutes)
5. Extract duration constants to AppDurations class (15 minutes)

**Total Time:** ~1 hour
**Impact:** Immediate perceived quality improvement

---

## Final Thoughts

The app shows attention to detail in visual design with the glassmorphism effects, consistent shadows, and thoughtful color palette. With focused improvements on performance and animations, Port-A-Thoughty can deliver an **iOS/Android app experience that feels premium and delightful**.

The architecture is clean enough that these improvements can be implemented incrementally without major refactoring. Start with the critical performance fixes, then layer in animations and polish for maximum impact.

Good luck with the improvements! 🚀
