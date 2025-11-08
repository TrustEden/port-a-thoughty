# Port-A-Thoughty: Recording Flow & Widget Implementation Overview

## 1. Current Recording Implementation

### 1.1 Recording Flow (In-App)

```
User Interface              State Management           Services
┌─────────────────┐        ┌─────────────────┐        ┌──────────────────┐
│  CaptureScreen  │        │ PortaThoughtyState      │ NativeSpeechToText│
│                 │        │                 │        │                  │
│ _RecordingButton│ ──────>│ startRecording()│ ──────>│ initialize()     │
│  (Tap to Start) │        │                 │        │ startListening() │
└─────────────────┘        └─────────────────┘        └──────────────────┘
        │                          ▲                            │
        │                          │                            │
        ├──> stopRecording() ──────┘                            │
        │                                                       │
        │    (Speech results callback)                          │
        └───────────────────────────<─────────────────────────┘
                                    |
                            _handleSpeechResult(text)
                                    |
                        Creates Note object:
                        - type: NoteType.voice
                        - text: transcribed text
                        - projectId: active project
                                    |
                    Inserts to LocalDatabase.insertNote()
                                    |
                    Updates UI & shows snackbar notification
```

**Key File**: `/home/user/port-a-thoughty/lib/screens/capture_screen.dart` (lines 130-147)
```dart
Center(
  child: _RecordingButton(
    isRecording: isRecording,
    onPressed: () async {
      if (isRecording) {
        await state.stopRecording();
      } else {
        await state.startRecording();
      }
    },
  ),
)
```

### 1.2 Recording Button Details

**File**: `/home/user/port-a-thoughty/lib/screens/capture_screen.dart` (lines 150-210)

- **Normal State**: Displays `assets/mic.png` (34x34)
- **Recording State**: Displays `assets/stoprecording.png` (34x34)
- **Animation**: Smooth size transition (86px → 72px) when recording starts
- **Background**: Animated radial gradient ring around button

### 1.3 State Management for Recording

**File**: `/home/user/port-a-thoughty/lib/state/app_state.dart`

#### Properties (lines 51-57)
```dart
late final NativeSpeechToTextService _speechService;
bool _isRecording = false;
String? _lastRecordingError;
String? _pendingRecordingMessage;
```

#### startRecording() method (lines 270-286)
```dart
Future<void> startRecording() async {
  await _ensureInitialized();
  if (_isRecording) return;
  _lastRecordingError = null;
  try {
    final hasPermission = await _speechService.initialize();
    if (hasPermission) {
      _speechService.startListening();
    } else {
      _lastRecordingError = 'Speech recognition permission not granted.';
      notifyListeners();
    }
  } catch (error) {
    _lastRecordingError = 'Failed to start speech recognition: $error';
    notifyListeners();
  }
}
```

#### stopRecording() method (lines 288-291)
```dart
Future<void> stopRecording() async {
  if (!_isRecording) return;
  _speechService.stopListening();
}
```

#### _handleSpeechResult() method (lines 585-604)
```dart
void _handleSpeechResult(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    _lastRecordingError = 'Speech recognition returned empty output.';
    notifyListeners();
    return;
  }

  final note = Note(
    projectId: _activeProjectId,
    type: NoteType.voice,
    text: trimmed,
    createdAt: DateTime.now(),
  );

  _database.insertNote(note);
  _notes = [note, ..._notes];
  _pendingRecordingMessage = 'Transcribed voice note added to your queue.';
  notifyListeners();
}
```

### 1.4 Speech-to-Text Service

**File**: `/home/user/port-a-thoughty/lib/services/native_speech_to_text.dart`

The service wraps Flutter's `speech_to_text` plugin with custom callbacks:

```dart
class NativeSpeechToTextService {
  NativeSpeechToTextService({
    required this.onResult,
    this.onListeningChanged,
    this.onWidgetUpdateNeeded,  // <-- For widget updates
  });

  final Function(String) onResult;
  final Function(bool)? onListeningChanged;
  final Function(bool)? onWidgetUpdateNeeded;  // <-- NEW

  Future<bool> initialize() async {
    return await _speechToText.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => _handleStatusChange(status),
    );
  }

  void startListening() {
    _speechToText.listen(
      onResult: _handleResult,
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 8),  // 8 sec silence timeout
    );
  }

  void stopListening() {
    _speechToText.stop();
  }
}
```

## 2. Asset Images Location

All images are in `/home/user/port-a-thoughty/assets/`:

```
assets/
├── capture.png              ← Navigation bar icon
├── stoprecording.png        ← Recording button (recording state)
├── mic.png                  ← Recording button (idle state)
├── written.png              ← Text note button
├── camera.png               ← Camera button
├── upload.png               ← Upload button
├── logo.png                 ← App launcher icon
├── mascot.png               ← For widget display
└── ... (other icons)
```

**Key Images for Recording**:
- `capture.png`: 48x48 - used in navigation bar
- `stoprecording.png`: 34x34 - recording button stop state
- `mic.png`: 34x34 - recording button idle state
- `mascot.png`: Could be used for 1x1 widget

## 3. Widget Implementation Status

### 3.1 Existing Widget Code

**Files Already Created**:
1. `/home/user/port-a-thoughty/android/app/src/main/java/com/example/porta_thoughty/widget/RecordWidgetProvider.kt` - Basic widget provider
2. `/home/user/port-a-thoughty/android/app/src/main/res/layout/record_widget.xml` - 1x1 widget layout
3. `/home/user/port-a-thoughty/android/app/src/main/res/xml/record_widget_info.xml` - Widget configuration

### 3.2 Current Widget Provider Implementation

**File**: `/home/user/port-a-thoughty/android/app/src/main/java/com/example/porta_thoughty/widget/RecordWidgetProvider.kt`

Current implementation:
- Opens app when tapped (using URI: `homeWidgetExample://home_widget/record`)
- Updates widget icon based on recording state
- No background recording capability yet

```kotlin
class RecordWidgetProvider : AppWidgetProvider() {
  override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    appWidgetIds.forEach { appWidgetId ->
      val views = RemoteViews(context.packageName, R.layout.record_widget).apply {
        val pendingIntent = PendingIntent.getActivity(
          context, 0,
          Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("homeWidgetExample://home_widget/record")
          },
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        setOnClickPendingIntent(R.id.record_button, pendingIntent)
      }
      appWidgetManager.updateAppWidget(appWidgetId, views)
    }
  }
}
```

### 3.3 Widget Layout

**File**: `/home/user/port-a-thoughty/android/app/src/main/res/layout/record_widget.xml`

```xml
<LinearLayout
  android:layout_width="match_parent"
  android:layout_height="match_parent"
  android:background="#0D7BCE"
  android:orientation="vertical"
  android:gravity="center"
  android:padding="8dp">

  <ImageButton
    android:id="@+id/record_button"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:src="@drawable/ic_mic_black_24dp"
    android:background="@android:color/transparent"
    android:contentDescription="Record" />
</LinearLayout>
```

### 3.4 Widget Info Configuration

**File**: `/home/user/port-a-thoughty/android/app/src/main/res/xml/record_widget_info.xml`

```xml
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
  android:initialLayout="@layout/record_widget"
  android:minWidth="40dp"
  android:minHeight="40dp"
  android:updatePeriodMillis="86400000"
  android:previewImage="@drawable/ic_mic_black_24dp"
  android:resizeMode="horizontal|vertical"
  android:widgetCategory="home_screen"
  android:widgetFeatures="reconfigurable"
  android:description="@string/app_widget_description" />
```

### 3.5 MainActivity Widget Integration

**File**: `/home/user/port-a-thoughty/android/app/src/main/kotlin/com/example/porta_thoughty/MainActivity.kt`

Already has MethodChannel support for widget updates:

```kotlin
private fun updateRecordWidget(context: Context, isRecording: Boolean) {
  val appWidgetManager = AppWidgetManager.getInstance(context)
  val componentName = ComponentName(context, RecordWidgetProvider::class.java)
  val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

  val updateIntent = Intent(context, RecordWidgetProvider::class.java).apply {
    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
    putExtra("isRecording", isRecording)
  }
  context.sendBroadcast(updateIntent)
}
```

## 4. Entry Point & Widget Interaction

### 4.1 Main Entry Point

**File**: `/home/user/port-a-thoughty/lib/main.dart`

The app is initialized with Provider state management:

```dart
class PortaThoughtyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PortaThoughtyState(),
      child: MaterialApp(
        title: 'Pot-A-Thoughty',
        theme: AppTheme.light(),
        home: const HomeShell(),
      ),
    );
  }
}
```

### 4.2 Widget Click Handling

**File**: `/home/user/port-a-thoughty/lib/main.dart` (lines 80-113)

Already has infrastructure for widget-triggered recording:

```dart
void _setupMethodChannel() {
  platform.setMethodCallHandler((call) async {
    print('MethodChannel call received: ${call.method}');
    if (call.method == "handleWidgetClick") {
      final String? uriString = call.arguments as String?;
      print('Received URI string: $uriString');
      if (uriString != null) {
        final Uri uri = Uri.parse(uriString);
        print('Parsed URI: $uri');
        if (uri.host == 'home_widget' && uri.pathSegments.contains('record')) {
          print('URI matches recording intent. Navigating to CaptureScreen.');
          _onDestinationSelected(1); // Navigate to CaptureScreen
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) {
              final state = Provider.of<PortaThoughtyState>(context, listen: false);
              if (!state.isRecording) {
                state.startRecording();
              }
            }
          });
        }
      }
    }
  });
}
```

## 5. Dependencies Related to Recording & Widgets

### 5.1 Current Dependencies

**File**: `/home/user/port-a-thoughty/pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2              # State management
  speech_to_text: ^7.3.0        # Voice recording & transcription
  sqflite: ^2.3.3               # Android/iOS database
  sqflite_common_ffi: ^2.3.2    # Desktop database
  path_provider: ^2.1.3         # File paths
  permission_handler: ^12.0.1   # Microphone permissions
  home_widget: ^0.8.1           # Widget support (ALREADY PRESENT!)
  uuid: ^4.5.1                  # Unique IDs
  flutter_dotenv: ^6.0.0        # Environment config
  http: ^1.2.0                  # HTTP requests
  share_plus: ^12.0.1           # Share functionality
  google_fonts: ^6.2.1          # Custom fonts
  google_mlkit_text_recognition: ^0.15.0  # OCR
  image_picker: ^1.1.2          # Image selection
  file_picker: ^8.1.6           # File selection
  receive_sharing_intent: ^1.8.1 # Share intent handling
```

**Key for Widget**: `home_widget: ^0.8.1` is already present!

### 5.2 Platform-Specific Dependencies

**Android Manifest**: Existing permissions for recording:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

**Android Manifest**: Needs for background recording:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

## 6. Recording Flow Summary

### Complete Recording Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│                        RECORDING LIFECYCLE                          │
└─────────────────────────────────────────────────────────────────────┘

USER ACTION
    │
    ├─ In-App: Tap _RecordingButton in CaptureScreen
    │
    └─ Widget: Tap home screen widget (FUTURE: implement foreground service)
            │
            └─> RecordWidgetProvider.onReceive()
                    │
                    └─> Start RecordingForegroundService (FUTURE)

    ▼

STATE: startRecording()
    │
    ├─ Check: is already recording? → return
    │
    ├─ Call: NativeSpeechToTextService.initialize()
    │   │
    │   └─ Request microphone permission
    │
    └─ Call: NativeSpeechToTextService.startListening()
        │
        ├─ Max duration: 2 minutes
        ├─ Silence timeout: 8 seconds
        └─ Continuous results enabled
                │
                └─ onListeningChanged callback → update _isRecording
                    │
                    └─ notifyListeners() → UI updates (recording button changes)
                        │
                        └─ Call: _sendWidgetUpdate(true) → update widget icon

    ▼

SPEECH RECOGNITION IN PROGRESS
    │
    ├─ Display notification (if widget-based) (FUTURE)
    │
    └─ Await speech results or timeout

    ▼

STATE: stopRecording()
    │
    ├─ Call: NativeSpeechToTextService.stopListening()
    │   │
    │   └─ Stop receiving audio input
    │
    └─ notifyListeners() → UI updates
        │
        └─ Call: _sendWidgetUpdate(false) → restore widget icon

    ▼

SPEECH RESULT RECEIVED
    │
    ├─ onResult callback → _handleSpeechResult(transcribedText)
    │
    ├─ Validate: text is not empty
    │
    ├─ Create: Note object
    │   ├─ projectId: current active project
    │   ├─ type: NoteType.voice
    │   ├─ text: transcribed text
    │   └─ createdAt: now
    │
    ├─ Database: _database.insertNote(note)
    │
    ├─ State: _notes = [note, ..._notes]
    │
    └─ Notify: _pendingRecordingMessage = 'Transcribed voice note added to your queue.'
            │
            └─ notifyListeners()
                    │
                    └─ CaptureScreen shows snackbar confirmation

    ▼

NOTE APPEARS IN QUEUE
    │
    └─ User can see note in Queue screen (sorted by newest first)
        │
        ├─ View: Full transcribed text
        ├─ Select: Multiple notes for batch processing
        └─ Action: Process selected notes into Markdown document
```

## 7. Widget Data Flow (Planned Implementation)

The planning document shows the intended widget flow:

```
WIDGET TAP
    │
    └─> RecordWidgetProvider.ACTION_RECORD_TOGGLE
            │
            └─> Start RecordingForegroundService
                    │
                    ├─ Show foreground notification
                    ├─ Start Android SpeechRecognizer
                    ├─ Silence detection: 8 seconds
                    ├─ Manual stop: tap widget again
                    └─ Max duration: 2 minutes
                            │
                            ▼
                    Stop service & save transcription to SharedPreferences
                            │
                            ├─ Send intent to MainActivity
                            │
                            ▼
                    MainActivity.onNewIntent() with SAVE_TRANSCRIPTION action
                            │
                            ├─ Call MethodChannel: saveWidgetTranscription()
                            │
                            ▼
                    PortaThoughtyState.saveWidgetTranscription(text, projectId)
                            │
                            ├─ Create Note object
                            ├─ Insert to database
                            ├─ Update local _notes list (if viewing that project)
                            │
                            ▼
                    Note appears in Flutter Queue
```

## 8. Key Implementation Points

### 8.1 What's Already Done
- ✅ MethodChannel infrastructure in place (`MainActivity.kt`)
- ✅ Widget layout XML files created
- ✅ Basic widget provider (opens app on tap)
- ✅ Recording button with state management
- ✅ Speech-to-text service with callbacks
- ✅ Asset images for recording (mic.png, stoprecording.png)
- ✅ home_widget dependency already added
- ✅ Planning document with 10 tasks outlined

### 8.2 What Needs Implementation
- ⚠️ RecordingForegroundService (Android native)
- ⚠️ WidgetConfigActivity for project selection
- ⚠️ SharedPreferences for project caching
- ⚠️ Widget state persistence (recording vs idle)
- ⚠️ 2x2 widget layout variant
- ⚠️ Project caching in app_state.dart
- ⚠️ Flutter integration method: saveWidgetTranscription()
- ⚠️ Mascot icon for widgets
- ⚠️ Error handling and polish

### 8.3 Architecture Summary

```
┌─────────────────────────────────────────────────────────┐
│              PORT-A-THOUGHTY WIDGET ARCHITECTURE        │
└─────────────────────────────────────────────────────────┘

Flutter Layer (Dart)
├─ lib/state/app_state.dart
│  ├─ startRecording() / stopRecording()
│  ├─ _handleSpeechResult()
│  ├─ saveWidgetTranscription() [NEEDED]
│  └─ _cacheProjectsForWidget() [NEEDED]
│
├─ lib/main.dart
│  └─ MethodChannel handlers
│     ├─ handleWidgetClick
│     ├─ updateWidget
│     └─ saveWidgetTranscription [NEEDED]
│
└─ lib/services/
   └─ native_speech_to_text.dart
      └─ Callbacks for recording state

    ▲
    │ MethodChannel: com.example.porta_thoughty/widget
    │ (updateWidget, saveWidgetTranscription)
    ▼

Android Native Layer (Kotlin)
├─ MainActivity.kt
│  ├─ configureFlutterEngine()
│  │  └─ MethodChannel setup ✅
│  │
│  └─ onNewIntent() [NEEDS UPDATE]
│     └─ Handle SAVE_TRANSCRIPTION action [NEEDED]
│
├─ RecordWidgetProvider.kt
│  ├─ onUpdate() - Initialize widget ✅ (basic)
│  ├─ onReceive() - Handle widget taps [NEEDS UPGRADE]
│  └─ updateAppWidget() [NEEDS IMPLEMENTATION]
│
├─ RecordingForegroundService.kt [NEEDS CREATION]
│  ├─ startRecording() → startSpeechRecognition()
│  ├─ stopRecording() → saveTranscription()
│  └─ onDestroy()
│
└─ WidgetConfigActivity.kt [NEEDS CREATION]
   ├─ Project selection dropdown
   └─ SharedPreferences storage

Resources Layer
├─ layout/record_widget.xml ✅ (basic 1x1)
├─ layout/record_widget_2x2.xml [NEEDED]
├─ xml/record_widget_info.xml ✅ (basic)
├─ xml/record_widget_2x2_info.xml [NEEDED]
├─ drawable/widget_background.xml [NEEDED]
└─ drawable/mascot_icon.xml [NEEDED]

Data Persistence
├─ SQLite (LocalDatabase) ✅ - Notes & projects
└─ SharedPreferences [NEEDS CONFIG]
   ├─ widget_prefs - Widget configurations
   └─ projects_cache - Project list for widget
```

