# Port-A-Thoughty File Structure Reference

## Recording & Widget Related Files

### Dart/Flutter Files

```
lib/
├── main.dart
│   ├── MethodChannel setup (line 50): 'com.example.porta_thoughty/widget'
│   ├── _setupMethodChannel() (lines 79-114) - Handles widget intents
│   ├── _initSharingListener() (lines 116-136) - Handles share intents
│   └── HomeShell class - Navigation, widget click handling
│
├── state/
│   └── app_state.dart
│       ├── PortaThoughtyState class (line 17)
│       ├── Properties:
│       │   ├── _speechService (line 51)
│       │   ├── _isRecording (line 53)
│       │   ├── _lastRecordingError (line 54)
│       │   └── _pendingRecordingMessage (line 55)
│       ├── startRecording() (line 270)
│       ├── stopRecording() (line 288)
│       ├── _handleSpeechResult() (line 585)
│       ├── _sendWidgetUpdate() (line 33) - Updates widget via MethodChannel
│       ├── MethodChannel declaration (line 18)
│       ├── Constructor with speech service setup (line 20)
│       └── _bootstrap() - Initialization sequence
│
├── screens/
│   └── capture_screen.dart
│       ├── CaptureScreen class (line 16)
│       ├── _SpeechCaptureCard (line 62)
│       │   └── Shows recording state and instructions
│       ├── _RecordingButton (line 150)
│       │   ├── Displays mic.png when idle
│       │   ├── Displays stoprecording.png when recording
│       │   ├── Animated circular gradient background
│       │   └── onPressed: startRecording() / stopRecording()
│       ├── _QuickActionsRow (line 212)
│       │   ├── Add text note
│       │   ├── Take photo
│       │   └── Upload file
│       └── RecentNoteList - Shows 5 most recent notes
│
├── services/
│   ├── native_speech_to_text.dart
│   │   ├── NativeSpeechToTextService class (line 6)
│   │   ├── Callbacks:
│   │   │   ├── onResult - Called when speech recognized
│   │   │   ├── onListeningChanged - Called when listening state changes
│   │   │   └── onWidgetUpdateNeeded - Called for widget updates
│   │   ├── initialize() (line 22) - Requests permissions
│   │   ├── startListening() (line 30)
│   │   │   ├── Duration: up to 2 minutes
│   │   │   └── Pause timeout: 8 seconds
│   │   ├── stopListening() (line 41)
│   │   ├── _handleResult() (line 55)
│   │   └── _handleStatusChange() (line 61)
│   │
│   ├── local_database.dart
│   │   ├── Stores notes in SQLite
│   │   ├── Tables: projects, notes, docs, settings
│   │   └── Methods: insertNote(), fetchActiveNotes(), etc.
│   │
│   └── doc_generator.dart
│       └── Generates Markdown from selected notes
│
├── models/
│   ├── note.dart
│   │   └── Note class with NoteType enum (voice, text, image)
│   ├── project.dart
│   │   └── Project class with name, color, icon
│   └── user_settings.dart
│       └── Settings like silence timeout
│
└── theme/
    └── app_theme.dart
        └── AppTheme.light() with gradient colors
```

### Android Native Files

```
android/app/src/main/
├── kotlin/com/example/porta_thoughty/
│   ├── MainActivity.kt
│   │   ├── Class: MainActivity extends FlutterActivity
│   │   ├── CHANNEL: "com.example.porta_thoughty/widget"
│   │   ├── configureFlutterEngine() (line 17)
│   │   │   ├── MethodChannel setup
│   │   │   ├── Handler for "updateWidget" method
│   │   │   └── Passes initial intent data to Flutter
│   │   ├── onNewIntent() (line 37) - Handles re-launch intents
│   │   └── updateRecordWidget() (line 45) - Broadcasts widget updates
│   │
│   └── widget/
│       ├── RecordWidgetProvider.kt
│       │   ├── Class: RecordWidgetProvider extends AppWidgetProvider
│       │   ├── onUpdate() (line 16) - Initialize widget
│       │   │   └── Sets up PendingIntent to open app
│       │   ├── onReceive() (line 34) - Handle broadcasts
│       │   │   └── Updates widget icon based on isRecording
│       │   └── URI format: homeWidgetExample://home_widget/record
│       │
│       ├── RecordingForegroundService.kt [NOT YET CREATED]
│       │   └── Needed for background recording
│       │
│       └── WidgetConfigActivity.kt [NOT YET CREATED]
│           └── Needed for project selection
│
├── res/
│   ├── layout/
│   │   ├── record_widget.xml
│   │   │   ├── Background: #0D7BCE (blue)
│   │   │   └── ImageButton for record_button
│   │   │
│   │   ├── record_widget_2x2.xml [NOT YET CREATED]
│   │   │   └── Larger variant with project name
│   │   │
│   │   ├── widget_config_activity.xml [NOT YET CREATED]
│   │   │   └── Project spinner dropdown
│   │   │
│   │   └── [Other layouts]
│   │
│   ├── xml/
│   │   ├── record_widget_info.xml
│   │   │   ├── minWidth/Height: 40dp
│   │   │   ├── resizeMode: horizontal|vertical
│   │   │   └── widgetCategory: home_screen
│   │   │
│   │   └── record_widget_2x2_info.xml [NOT YET CREATED]
│   │       ├── minWidth/Height: 110dp
│   │       └── configure: WidgetConfigActivity
│   │
│   ├── drawable/
│   │   ├── ic_mic_black_24dp.xml (or .png)
│   │   ├── ic_stop_black_24dp.xml (or .png)
│   │   │
│   │   ├── widget_background.xml [NOT YET CREATED]
│   │   │   └── Rounded rectangle for widget bg
│   │   │
│   │   └── mascot_icon.xml [NOT YET CREATED]
│   │       └── Vector drawable for widget
│   │
│   └── values/
│       └── strings.xml
│           └── app_widget_description (referenced)
│
└── AndroidManifest.xml
    ├── Existing permissions:
    │   ├── android.permission.RECORD_AUDIO ✅
    │   └── android.permission.INTERNET ✅
    │
    ├── Needed permissions:
    │   ├── android.permission.FOREGROUND_SERVICE
    │   ├── android.permission.FOREGROUND_SERVICE_MICROPHONE
    │   ├── android.permission.POST_NOTIFICATIONS
    │   ├── android.permission.WAKE_LOCK
    │   └── android.permission.MODIFY_AUDIO_SETTINGS
    │
    ├── MainActivity activity ✅
    │
    ├── RecordWidgetProvider receiver ✅
    │   └── Metadata: android.appwidget.provider
    │
    ├── RecordingForegroundService [NOT YET CREATED]
    │   └── foregroundServiceType: microphone
    │
    └── WidgetConfigActivity [NOT YET CREATED]
        └── Intent filter: APPWIDGET_CONFIGURE
```

### Asset Files

```
assets/
├── mic.png
│   └── Recording button idle state (34x34)
│
├── stoprecording.png
│   └── Recording button recording state (34x34)
│
├── capture.png
│   └── Navigation bar Capture icon (48x48)
│
├── mascot.png
│   └── Mascot for 1x1 widget
│
├── logo.png
│   └── App launcher icon
│
├── written.png
│   └── Text note quick action
│
├── camera.png
│   └── Camera quick action
│
└── ... other assets
```

### Configuration Files

```
pubspec.yaml (line 1)
├── Dependencies:
│   ├── provider: ^6.1.2 ✅
│   ├── speech_to_text: ^7.3.0 ✅
│   ├── home_widget: ^0.8.1 ✅ (Already included!)
│   ├── permission_handler: ^12.0.1 ✅
│   └── ... other dependencies
│
└── Assets:
    └── assets/ (all image assets included)
```

### Documentation Files

```
docs/
├── plans/2025-11-06-home-screen-recording-widget.md
│   └── 10-task implementation plan (COMPREHENSIVE)
│
├── recording-widget-overview.md [NEWLY CREATED]
│   └── Current state & architecture
│
└── file-structure-reference.md [THIS FILE]
    └── File locations & relationships
```

## Key File Relationships

### Recording State Flow

```
CaptureScreen (_RecordingButton)
    ↓ [onPressed]
PortaThoughtyState.startRecording()
    ↓
NativeSpeechToTextService.startListening()
    ↓ [speech recognition]
NativeSpeechToTextService.onResult callback
    ↓
PortaThoughtyState._handleSpeechResult(text)
    ↓
LocalDatabase.insertNote(note)
    ↓
CaptureScreen (shows confirmation)
```

### Widget Update Flow

```
PortaThoughtyState._sendWidgetUpdate(isRecording)
    ↓ [MethodChannel invoke]
MainActivity.MethodChannel handler
    ↓
MainActivity.updateRecordWidget(isRecording)
    ↓ [broadcast intent]
RecordWidgetProvider.onReceive()
    ↓
RecordWidgetProvider updates UI (icon change)
```

### Widget Future Flow

```
RecordWidgetProvider.onReceive() [widget tap]
    ↓
RecordingForegroundService.onStartCommand()
    ↓
RecordingForegroundService.startRecording()
    ↓
Android SpeechRecognizer (native)
    ↓
RecordingForegroundService.saveTranscription()
    ↓ [intent + MethodChannel]
MainActivity.onNewIntent("SAVE_TRANSCRIPTION")
    ↓
PortaThoughtyState.saveWidgetTranscription()
    ↓
LocalDatabase.insertNote()
    ↓
Queue screen shows note
```

## Important Line Numbers & Methods

### In-App Recording (COMPLETE)

| File | Line | Method | Purpose |
|------|------|--------|---------|
| capture_screen.dart | 130 | _RecordingButton | Recording button UI |
| capture_screen.dart | 194 | onPressed | Start/stop recording |
| app_state.dart | 20 | Constructor | Initialize speech service |
| app_state.dart | 270 | startRecording() | Begin recording |
| app_state.dart | 288 | stopRecording() | Stop recording |
| app_state.dart | 585 | _handleSpeechResult() | Save transcribed note |
| app_state.dart | 33 | _sendWidgetUpdate() | Update widget UI |
| native_speech_to_text.dart | 30 | startListening() | Start speech recognition |
| native_speech_to_text.dart | 41 | stopListening() | Stop speech recognition |

### Widget Infrastructure (PARTIAL)

| File | Status | Purpose |
|------|--------|---------|
| main.dart (line 50) | ✅ | MethodChannel declaration |
| main.dart (lines 79-114) | ✅ | Widget click handler |
| MainActivity.kt (line 14) | ✅ | CHANNEL constant |
| MainActivity.kt (line 20) | ✅ | MethodChannel setup |
| MainActivity.kt (line 45) | ✅ | updateRecordWidget() |
| RecordWidgetProvider.kt | ✅ | Basic widget provider |
| record_widget.xml | ✅ | 1x1 layout |
| record_widget_info.xml | ✅ | Widget config |
| RecordingForegroundService.kt | ❌ | Background service |
| WidgetConfigActivity.kt | ❌ | Project selection |
| record_widget_2x2.xml | ❌ | 2x2 layout |

## Next Steps for Widget Implementation

1. **Create RecordingForegroundService.kt** - Handle background recording
2. **Create WidgetConfigActivity.kt** - Project selection UI
3. **Update RecordWidgetProvider.kt** - Add RECORD_TOGGLE action
4. **Create 2x2 widget layouts** - Large variant support
5. **Add SharedPreferences** - Store widget configuration
6. **Update app_state.dart** - Add saveWidgetTranscription()
7. **Create mascot icon** - Visual improvement
8. **Add documentation** - User guides & testing checklists

See `docs/plans/2025-11-06-home-screen-recording-widget.md` for detailed 10-task plan.
