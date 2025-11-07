# Home Screen Recording Widget Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a functional home screen widget (1x1 and 2x2) that allows voice recording with project selection, silence detection, and automatic transcription to queue without opening the app.

**Architecture:** This implementation extends the existing Android widget infrastructure to support background recording via a foreground service. The widget will use SharedPreferences for state persistence, Android WorkManager for background coordination, and the existing Flutter MethodChannel bridge to save transcribed notes. The widget displays the mascot/logo, provides project selection via widget configuration, and handles three stop conditions: silence timeout, manual stop, or 2-minute maximum duration.

**Tech Stack:**
- Flutter + Provider (existing state management)
- Android Native (Kotlin) - Foreground Service with SpeechRecognizer
- SharedPreferences (widget state persistence)
- MethodChannel (Flutter ↔ Native bridge)
- home_widget package (already integrated)

**Platform Support:** Android only (iOS widgets have different architecture and limitations for background recording)

---

## Task 1: Add Required Dependencies and Permissions

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Step 1: Add shared_preferences to pubspec.yaml**

Open `pubspec.yaml` and add the dependency after the existing `home_widget` dependency:

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  speech_to_text: ^7.3.0
  sqflite: ^2.3.3
  sqflite_common_ffi: ^2.3.2
  path_provider: ^2.1.3
  home_widget: ^0.8.1
  shared_preferences: ^2.3.3  # ADD THIS LINE
  uuid: ^4.5.1
  permission_handler: ^12.0.1
  # ... rest of dependencies
```

**Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: "Running 'flutter pub get' in porta_thoughty..." success message

**Step 3: Update AndroidManifest.xml with new permissions**

Open `android/app/src/main/AndroidManifest.xml` and add these permissions before the `<application>` tag:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Existing permissions -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />

    <!-- ADD THESE NEW PERMISSIONS -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

    <application>
        <!-- ... -->
    </application>
</manifest>
```

**Step 4: Declare foreground service in AndroidManifest.xml**

Inside the `<application>` tag in `android/app/src/main/AndroidManifest.xml`, add the service declaration after the existing `RecordWidgetProvider` receiver:

```xml
<application>
    <!-- ... existing activity and receiver ... -->

    <!-- Existing widget receiver -->
    <receiver android:name=".widget.RecordWidgetProvider"
              android:exported="true">
        <intent-filter>
            <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
        </intent-filter>
        <meta-data
            android:name="android.appwidget.provider"
            android:resource="@xml/record_widget_info" />
    </receiver>

    <!-- ADD THIS SERVICE DECLARATION -->
    <service
        android:name=".widget.RecordingForegroundService"
        android:enabled="true"
        android:exported="false"
        android:foregroundServiceType="microphone">
    </service>
</application>
```

**Step 5: Commit dependency and permission changes**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "feat: add shared_preferences and recording service permissions"
```

---

## Task 2: Create Widget Configuration Activity (Project Selection)

**Files:**
- Create: `android/app/src/main/kotlin/com/example/porta_thoughty/widget/WidgetConfigActivity.kt`
- Create: `android/app/src/main/res/layout/widget_config_activity.xml`

**Step 1: Create widget configuration layout**

Create file `android/app/src/main/res/layout/widget_config_activity.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp"
    android:background="#FFFFFF">

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Choose Recording Project"
        android:textSize="20sp"
        android:textStyle="bold"
        android:textColor="#000000"
        android:paddingBottom="16dp" />

    <TextView
        android:id="@+id/project_label"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Default Project:"
        android:textSize="16sp"
        android:textColor="#666666"
        android:paddingBottom="8dp" />

    <Spinner
        android:id="@+id/project_spinner"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:minHeight="48dp"
        android:background="@android:drawable/btn_dropdown"
        android:padding="12dp" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="end"
        android:paddingTop="24dp">

        <Button
            android:id="@+id/cancel_button"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="Cancel"
            android:layout_marginEnd="8dp"
            style="?android:attr/buttonBarButtonStyle" />

        <Button
            android:id="@+id/add_button"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="Add Widget"
            style="?android:attr/buttonBarButtonStyle" />
    </LinearLayout>

    <TextView
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="Tap the widget to start recording. Recording stops after silence, manual tap, or 2 minutes."
        android:textSize="12sp"
        android:textColor="#999999"
        android:paddingTop="16dp" />
</LinearLayout>
```

**Step 2: Create WidgetConfigActivity.kt**

Create file `android/app/src/main/kotlin/com/example/porta_thoughty/widget/WidgetConfigActivity.kt`:

```kotlin
package com.example.porta_thoughty.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.*
import com.example.porta_thoughty.R

class WidgetConfigActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var projectSpinner: Spinner

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        setContentView(R.layout.widget_config_activity)

        // Get widget ID from intent
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
        }

        // If widget ID is invalid, finish
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // Setup spinner with projects
        projectSpinner = findViewById(R.id.project_spinner)
        loadProjects()

        // Setup buttons
        findViewById<Button>(R.id.cancel_button).setOnClickListener {
            finish()
        }

        findViewById<Button>(R.id.add_button).setOnClickListener {
            saveWidgetConfig()
        }
    }

    private fun loadProjects() {
        // Load projects from SharedPreferences
        val prefs = getSharedPreferences("porta_thoughty_prefs", Context.MODE_PRIVATE)
        val projectsJson = prefs.getString("projects_cache", null)

        val projects = if (projectsJson != null) {
            parseProjectsFromJson(projectsJson)
        } else {
            // Default to "Inbox" if no projects cached
            listOf("Inbox" to "default_inbox_id")
        }

        val projectNames = projects.map { it.first }
        val projectIds = projects.map { it.second }

        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, projectNames)
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        projectSpinner.adapter = adapter

        // Store project IDs for later retrieval
        projectSpinner.tag = projectIds
    }

    private fun parseProjectsFromJson(json: String): List<Pair<String, String>> {
        // Simple JSON parsing for project list
        // Format: [{"id":"xxx","name":"Inbox"},{"id":"yyy","name":"Work"}]
        val projects = mutableListOf<Pair<String, String>>()

        try {
            val cleaned = json.trim().removePrefix("[").removeSuffix("]")
            val items = cleaned.split("},")

            for (item in items) {
                val idMatch = Regex("\"id\":\"([^\"]+)\"").find(item)
                val nameMatch = Regex("\"name\":\"([^\"]+)\"").find(item)

                if (idMatch != null && nameMatch != null) {
                    projects.add(nameMatch.groupValues[1] to idMatch.groupValues[1])
                }
            }
        } catch (e: Exception) {
            // Fallback to Inbox on parse error
            projects.add("Inbox" to "default_inbox_id")
        }

        return projects
    }

    private fun saveWidgetConfig() {
        val position = projectSpinner.selectedItemPosition
        val projectIds = projectSpinner.tag as List<String>
        val selectedProjectId = projectIds[position]
        val selectedProjectName = projectSpinner.selectedItem as String

        // Save to SharedPreferences
        val prefs = getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("project_id_$appWidgetId", selectedProjectId)
            .putString("project_name_$appWidgetId", selectedProjectName)
            .apply()

        // Update widget
        val appWidgetManager = AppWidgetManager.getInstance(this)
        RecordWidgetProvider.updateAppWidget(this, appWidgetManager, appWidgetId, false)

        // Return success
        val resultValue = Intent()
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)
        finish()
    }
}
```

**Step 3: Update record_widget_info.xml to use configuration activity**

Open `android/app/src/main/res/xml/record_widget_info.xml` and add the configure attribute:

```xml
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="40dp"
    android:minHeight="40dp"
    android:updatePeriodMillis="86400000"
    android:initialLayout="@layout/record_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:configure="com.example.porta_thoughty.widget.WidgetConfigActivity">
</appwidget-provider>
```

**Step 4: Register WidgetConfigActivity in AndroidManifest.xml**

Add inside `<application>` tag in `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".widget.WidgetConfigActivity"
    android:exported="false">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_CONFIGURE" />
    </intent-filter>
</activity>
```

**Step 5: Commit widget configuration activity**

```bash
git add android/app/src/main/kotlin/com/example/porta_thoughty/widget/WidgetConfigActivity.kt android/app/src/main/res/layout/widget_config_activity.xml android/app/src/main/res/xml/record_widget_info.xml android/app/src/main/AndroidManifest.xml
git commit -m "feat: add widget configuration activity for project selection"
```

---

## Task 3: Create Foreground Recording Service

**Files:**
- Create: `android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordingForegroundService.kt`

**Step 1: Create RecordingForegroundService.kt**

Create file `android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordingForegroundService.kt`:

```kotlin
package com.example.porta_thoughty.widget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.NotificationCompat
import com.example.porta_thoughty.MainActivity
import com.example.porta_thoughty.R
import java.util.*
import kotlin.concurrent.schedule

class RecordingForegroundService : Service() {

    private var speechRecognizer: SpeechRecognizer? = null
    private var widgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID
    private var projectId: String = ""
    private var projectName: String = "Inbox"
    private var maxDurationTimer: TimerTask? = null
    private var transcribedText: String = ""

    companion object {
        const val CHANNEL_ID = "recording_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START_RECORDING = "com.example.porta_thoughty.START_RECORDING"
        const val ACTION_STOP_RECORDING = "com.example.porta_thoughty.STOP_RECORDING"
        const val EXTRA_WIDGET_ID = "widget_id"
        const val EXTRA_PROJECT_ID = "project_id"
        const val EXTRA_PROJECT_NAME = "project_name"
        const val MAX_RECORDING_DURATION_MS = 120000L // 2 minutes
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_RECORDING -> {
                widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                projectId = intent.getStringExtra(EXTRA_PROJECT_ID) ?: ""
                projectName = intent.getStringExtra(EXTRA_PROJECT_NAME) ?: "Inbox"
                startRecording()
            }
            ACTION_STOP_RECORDING -> {
                stopRecording()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Recording Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when recording voice notes"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startRecording() {
        // Create stop intent
        val stopIntent = Intent(this, RecordingForegroundService::class.java).apply {
            action = ACTION_STOP_RECORDING
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Create notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Recording to $projectName")
            .setContentText("Tap to stop recording")
            .setSmallIcon(R.drawable.ic_mic_black_24dp)
            .setOngoing(true)
            .addAction(R.drawable.ic_stop_black_24dp, "Stop", stopPendingIntent)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        // Update widget to show recording state
        updateWidget(true)

        // Initialize speech recognizer
        startSpeechRecognition()

        // Set max duration timer (2 minutes)
        maxDurationTimer = Timer().schedule(MAX_RECORDING_DURATION_MS) {
            stopRecording()
        }
    }

    private fun startSpeechRecognition() {
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)

        val recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 8000) // 8 seconds silence
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 8000)
        }

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                // Recording started
            }

            override fun onBeginningOfSpeech() {
                // User started speaking
            }

            override fun onRmsChanged(rmsdB: Float) {
                // Volume changed (could be used for UI feedback)
            }

            override fun onBufferReceived(buffer: ByteArray?) {
                // Not used
            }

            override fun onEndOfSpeech() {
                // User stopped speaking (silence detected)
                stopRecording()
            }

            override fun onError(error: Int) {
                // Handle errors
                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH -> {
                        // No speech detected - stop
                        stopRecording()
                    }
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                        // Timeout - stop
                        stopRecording()
                    }
                    else -> {
                        // Other errors - stop
                        stopRecording()
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                // Final results
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    transcribedText = matches[0]
                    saveTranscription()
                }
                stopRecording()
            }

            override fun onPartialResults(partialResults: Bundle?) {
                // Partial results (optional - could update notification)
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    transcribedText = matches[0]
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {
                // Not used
            }
        })

        speechRecognizer?.startListening(recognizerIntent)
    }

    private fun stopRecording() {
        // Cancel max duration timer
        maxDurationTimer?.cancel()
        maxDurationTimer = null

        // Stop speech recognition
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null

        // Update widget to show stopped state
        updateWidget(false)

        // Stop foreground service
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun saveTranscription() {
        if (transcribedText.isBlank()) {
            return
        }

        // Save to SharedPreferences for Flutter to pick up
        val prefs = getSharedPreferences("widget_recordings", Context.MODE_PRIVATE)
        val timestamp = System.currentTimeMillis()

        prefs.edit()
            .putString("pending_transcription_$timestamp", transcribedText)
            .putString("pending_project_id_$timestamp", projectId)
            .putLong("pending_timestamp", timestamp)
            .apply()

        // Notify Flutter app via broadcast or MethodChannel
        // Since we can't directly call MethodChannel from service, we'll use an intent
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "com.example.porta_thoughty.SAVE_TRANSCRIPTION"
            putExtra("transcription", transcribedText)
            putExtra("project_id", projectId)
            putExtra("timestamp", timestamp)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(intent)
    }

    private fun updateWidget(isRecording: Boolean) {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            RecordWidgetProvider.updateAppWidget(this, appWidgetManager, widgetId, isRecording)
        } else {
            // Update all widgets
            val componentName = ComponentName(this, RecordWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (id in widgetIds) {
                RecordWidgetProvider.updateAppWidget(this, appWidgetManager, id, isRecording)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
        maxDurationTimer?.cancel()
    }
}
```

**Step 2: Verify service is declared in AndroidManifest.xml**

Ensure the service declaration from Task 1 Step 4 is present in `android/app/src/main/AndroidManifest.xml`.

**Step 3: Commit foreground service**

```bash
git add android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordingForegroundService.kt
git commit -m "feat: create foreground service for background voice recording"
```

---

## Task 4: Update Widget Provider to Handle Recording States

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordWidgetProvider.kt`
- Modify: `android/app/src/main/res/layout/record_widget.xml`
- Create: `android/app/src/main/res/drawable/widget_background.xml`
- Create: `android/app/src/main/res/layout/record_widget_2x2.xml`

**Step 1: Create widget background drawable**

Create file `android/app/src/main/res/drawable/widget_background.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#0D7BCE" />
    <corners android:radius="16dp" />
</shape>
```

**Step 2: Update 1x1 widget layout with mascot/logo**

Update `android/app/src/main/res/layout/record_widget.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center"
    android:background="@drawable/widget_background"
    android:padding="8dp">

    <ImageButton
        android:id="@+id/widget_button"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:minWidth="48dp"
        android:minHeight="48dp"
        android:src="@drawable/ic_mic_black_24dp"
        android:background="?android:attr/selectableItemBackgroundBorderless"
        android:contentDescription="Record voice note"
        android:scaleType="centerInside"
        android:tint="#FFFFFF" />
</LinearLayout>
```

**Step 3: Create 2x2 widget layout with project name**

Create file `android/app/src/main/res/layout/record_widget_2x2.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center"
    android:background="@drawable/widget_background"
    android:padding="16dp">

    <TextView
        android:id="@+id/widget_title"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Porta-Thoughty"
        android:textColor="#FFFFFF"
        android:textSize="16sp"
        android:textStyle="bold"
        android:paddingBottom="8dp" />

    <ImageButton
        android:id="@+id/widget_button"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:minWidth="56dp"
        android:minHeight="56dp"
        android:src="@drawable/ic_mic_black_24dp"
        android:background="?android:attr/selectableItemBackgroundBorderless"
        android:contentDescription="Record voice note"
        android:scaleType="centerInside"
        android:tint="#FFFFFF" />

    <TextView
        android:id="@+id/widget_project_name"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Inbox"
        android:textColor="#E0E0E0"
        android:textSize="12sp"
        android:paddingTop="8dp" />
</LinearLayout>
```

**Step 4: Create 2x2 widget configuration**

Create file `android/app/src/main/res/xml/record_widget_2x2_info.xml`:

```xml
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="86400000"
    android:initialLayout="@layout/record_widget_2x2"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:configure="com.example.porta_thoughty.widget.WidgetConfigActivity">
</appwidget-provider>
```

**Step 5: Rewrite RecordWidgetProvider.kt to handle both widget sizes and recording**

Replace the entire contents of `android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordWidgetProvider.kt`:

```kotlin
package com.example.porta_thoughty.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.example.porta_thoughty.R

class RecordWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_RECORD_TOGGLE = "com.example.porta_thoughty.RECORD_TOGGLE"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            isRecording: Boolean
        ) {
            val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            val projectId = prefs.getString("project_id_$appWidgetId", "default_inbox_id") ?: "default_inbox_id"
            val projectName = prefs.getString("project_name_$appWidgetId", "Inbox") ?: "Inbox"

            // Determine widget size (check if 2x2 layout is used)
            val widgetOptions = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = widgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val is2x2 = minWidth >= 110

            // Choose layout
            val layoutId = if (is2x2) R.layout.record_widget_2x2 else R.layout.record_widget
            val views = RemoteViews(context.packageName, layoutId)

            // Set button icon based on recording state
            val iconRes = if (isRecording) {
                R.drawable.ic_stop_black_24dp
            } else {
                R.drawable.ic_mic_black_24dp
            }
            views.setImageViewResource(R.id.widget_button, iconRes)

            // Update project name for 2x2 widget
            if (is2x2) {
                views.setTextViewText(R.id.widget_project_name, projectName)
            }

            // Create click intent
            val intent = Intent(context, RecordWidgetProvider::class.java).apply {
                action = ACTION_RECORD_TOGGLE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra("project_id", projectId)
                putExtra("project_name", projectName)
                putExtra("is_recording", isRecording)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_button, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, false)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_RECORD_TOGGLE) {
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            val projectId = intent.getStringExtra("project_id") ?: ""
            val projectName = intent.getStringExtra("project_name") ?: "Inbox"
            val isRecording = intent.getBooleanExtra("is_recording", false)

            if (isRecording) {
                // Stop recording
                val stopIntent = Intent(context, RecordingForegroundService::class.java).apply {
                    action = RecordingForegroundService.ACTION_STOP_RECORDING
                }
                context.startService(stopIntent)
            } else {
                // Start recording
                val startIntent = Intent(context, RecordingForegroundService::class.java).apply {
                    action = RecordingForegroundService.ACTION_START_RECORDING
                    putExtra(RecordingForegroundService.EXTRA_WIDGET_ID, widgetId)
                    putExtra(RecordingForegroundService.EXTRA_PROJECT_ID, projectId)
                    putExtra(RecordingForegroundService.EXTRA_PROJECT_NAME, projectName)
                }
                context.startForegroundService(startIntent)
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        for (widgetId in appWidgetIds) {
            editor.remove("project_id_$widgetId")
            editor.remove("project_name_$widgetId")
        }
        editor.apply()
    }
}
```

**Step 6: Register 2x2 widget receiver in AndroidManifest.xml**

Add a second receiver entry in `android/app/src/main/AndroidManifest.xml` inside `<application>`:

```xml
<!-- Existing 1x1 widget receiver -->
<receiver android:name=".widget.RecordWidgetProvider"
          android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/record_widget_info" />
</receiver>

<!-- ADD THIS: 2x2 widget receiver -->
<receiver android:name=".widget.RecordWidgetProvider"
          android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/record_widget_2x2_info" />
</receiver>
```

**Step 7: Commit widget provider updates**

```bash
git add android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordWidgetProvider.kt android/app/src/main/res/layout/record_widget.xml android/app/src/main/res/layout/record_widget_2x2.xml android/app/src/main/res/xml/record_widget_2x2_info.xml android/app/src/main/res/drawable/widget_background.xml android/app/src/main/AndroidManifest.xml
git commit -m "feat: update widget provider with 1x1 and 2x2 layouts"
```

---

## Task 5: Flutter Integration - Handle Widget Transcriptions

**Files:**
- Modify: `lib/state/app_state.dart`
- Modify: `lib/main.dart`

**Step 1: Add method to save widget transcription in app_state.dart**

Open `lib/state/app_state.dart` and add this method after the existing `_handleSpeechResult` method (around line 551):

```dart
/// Save a transcription from widget recording
Future<void> saveWidgetTranscription(String text, String projectId) async {
  await _ensureInitialized();

  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return;
  }

  // Find the project or use active project as fallback
  String targetProjectId = projectId;
  if (!_projects.any((p) => p.id == projectId)) {
    targetProjectId = _activeProjectId;
  }

  final note = Note(
    projectId: targetProjectId,
    type: NoteType.voice,
    text: trimmed,
    createdAt: DateTime.now(),
  );

  await _database.insertNote(note);

  // Only update UI if we're viewing this project
  if (targetProjectId == _activeProjectId) {
    _notes = [note, ..._notes];
  }

  notifyListeners();
}
```

**Step 2: Add MethodChannel handler for widget transcriptions in main.dart**

Open `lib/main.dart` and find the `configureFlutterEngine` method (around line 72). Update the MethodChannel handler to include the new action:

Find this block:
```dart
methodChannel.setMethodCallHandler((call) async {
  if (call.method == 'handleWidgetClick') {
    final uri = call.arguments as String?;
    if (uri != null && uri.contains('record')) {
      navigatorKey.currentState?.pushNamed('/');
      final state = Provider.of<PortaThoughtyState>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await state.startRecording();
    }
  }
});
```

Replace it with:
```dart
methodChannel.setMethodCallHandler((call) async {
  if (call.method == 'handleWidgetClick') {
    final uri = call.arguments as String?;
    if (uri != null && uri.contains('record')) {
      navigatorKey.currentState?.pushNamed('/');
      final state = Provider.of<PortaThoughtyState>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await state.startRecording();
    }
  } else if (call.method == 'saveWidgetTranscription') {
    // Handle transcription from widget recording
    final transcription = call.arguments['transcription'] as String?;
    final projectId = call.arguments['project_id'] as String?;

    if (transcription != null && projectId != null) {
      final state = Provider.of<PortaThoughtyState>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await state.saveWidgetTranscription(transcription, projectId);
    }
  }
});
```

**Step 3: Update MainActivity.kt to handle transcription intent**

Open `android/app/src/main/kotlin/com/example/porta_thoughty/MainActivity.kt` and update the `onNewIntent` method to handle the SAVE_TRANSCRIPTION action:

Find the existing `onNewIntent` method and update it:

```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)

    when (intent.action) {
        "android.intent.action.VIEW" -> {
            val uri = intent.data?.toString()
            if (uri != null) {
                methodChannel.invokeMethod("handleWidgetClick", uri)
            }
        }
        "com.example.porta_thoughty.SAVE_TRANSCRIPTION" -> {
            val transcription = intent.getStringExtra("transcription")
            val projectId = intent.getStringExtra("project_id")

            if (transcription != null && projectId != null) {
                val args = mapOf(
                    "transcription" to transcription,
                    "project_id" to projectId
                )
                methodChannel.invokeMethod("saveWidgetTranscription", args)
            }
        }
    }
}
```

**Step 4: Commit Flutter integration changes**

```bash
git add lib/state/app_state.dart lib/main.dart android/app/src/main/kotlin/com/example/porta_thoughty/MainActivity.kt
git commit -m "feat: integrate widget transcriptions with Flutter app state"
```

---

## Task 6: Add Project Caching for Widget Configuration

**Files:**
- Modify: `lib/state/app_state.dart`

**Step 1: Add shared_preferences import to app_state.dart**

Open `lib/state/app_state.dart` and add the import at the top:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';  // ADD THIS
import '../models/note.dart';
import '../models/project.dart';
import '../models/processed_doc.dart';
import '../models/user_settings.dart';
import '../services/local_database.dart';
import '../services/native_speech_to_text.dart';
import '../services/doc_generator.dart';
```

**Step 2: Add project caching method in app_state.dart**

Add this method after `_ensureInitialized()` (around line 66):

```dart
/// Cache projects to SharedPreferences for widget access
Future<void> _cacheProjectsForWidget() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Create simple JSON representation of projects
    final projectsJson = _projects.map((p) {
      return '{"id":"${p.id}","name":"${p.name}"}';
    }).toList();

    final json = '[${projectsJson.join(',')}]';
    await prefs.setString('projects_cache', json);
  } catch (e) {
    print('Failed to cache projects: $e');
  }
}
```

**Step 3: Call caching method when projects are loaded**

Find the `_bootstrap()` method (around line 51) and update it to call the caching method:

```dart
Future<void> _bootstrap() async {
  _database = await LocalDatabase.init();
  await _loadSettings();
  _projects = await _database.fetchProjects();

  // Cache projects for widget
  await _cacheProjectsForWidget();  // ADD THIS LINE

  if (_projects.isEmpty) {
    final defaultProject = await _database.ensureDefaultProject();
    _projects = [defaultProject];
    await _cacheProjectsForWidget();  // ADD THIS LINE
  }

  _activeProjectId = _projects.first.id;
  await _loadNotesAndDocs();
  notifyListeners();
}
```

**Step 4: Call caching when projects change**

Find the `createProject()` method (around line 178) and add the caching call:

```dart
Future<void> createProject(Project project) async {
  await _ensureInitialized();
  await _database.insertProject(project);
  _projects = await _database.fetchProjects();
  await _cacheProjectsForWidget();  // ADD THIS LINE
  notifyListeners();
}
```

Also update `deleteProject()` method (around line 186):

```dart
Future<void> deleteProject(String projectId) async {
  await _ensureInitialized();
  if (_projects.length == 1) {
    return;
  }
  await _database.deleteProject(projectId);
  _projects = await _database.fetchProjects();
  await _cacheProjectsForWidget();  // ADD THIS LINE

  if (_activeProjectId == projectId) {
    _activeProjectId = _projects.first.id;
    await _loadNotesAndDocs();
  }
  notifyListeners();
}
```

**Step 5: Commit project caching changes**

```bash
git add lib/state/app_state.dart
git commit -m "feat: cache projects to SharedPreferences for widget access"
```

---

## Task 7: Add Mascot/Logo to Widget (Optional Enhancement)

**Files:**
- Add: `android/app/src/main/res/drawable/mascot_icon.xml` or `mascot_icon.png`
- Modify: `android/app/src/main/res/layout/record_widget_2x2.xml`

**Step 1: Create placeholder mascot icon (vector drawable)**

Create file `android/app/src/main/res/drawable/mascot_icon.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp"
    android:height="48dp"
    android:viewportWidth="48"
    android:viewportHeight="48">

    <!-- Simple robot/mascot head placeholder -->
    <!-- Circle for head -->
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M24,8 A16,16 0 0,1 40,24 A16,16 0 0,1 24,40 A16,16 0 0,1 8,24 A16,16 0 0,1 24,8 Z" />

    <!-- Eyes -->
    <path
        android:fillColor="#0D7BCE"
        android:pathData="M18,20 A3,3 0 0,1 18,26 A3,3 0 0,1 18,20 Z" />
    <path
        android:fillColor="#0D7BCE"
        android:pathData="M30,20 A3,3 0 0,1 30,26 A3,3 0 0,1 30,20 Z" />

    <!-- Smile -->
    <path
        android:fillColor="@android:color/transparent"
        android:strokeColor="#0D7BCE"
        android:strokeWidth="2"
        android:pathData="M16,28 Q24,34 32,28" />

    <!-- Antenna -->
    <path
        android:fillColor="@android:color/transparent"
        android:strokeColor="#FFFFFF"
        android:strokeWidth="2"
        android:pathData="M24,8 L24,2" />
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M24,2 A2,2 0 0,1 24,6 A2,2 0 0,1 24,2 Z" />
</vector>
```

**Step 2: Update 2x2 widget layout to show mascot**

Update `android/app/src/main/res/layout/record_widget_2x2.xml` to include the mascot:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:gravity="center"
    android:background="@drawable/widget_background"
    android:padding="16dp">

    <!-- ADD MASCOT IMAGE -->
    <ImageView
        android:id="@+id/widget_mascot"
        android:layout_width="32dp"
        android:layout_height="32dp"
        android:src="@drawable/mascot_icon"
        android:contentDescription="Porta-Thoughty mascot"
        android:layout_marginBottom="4dp" />

    <TextView
        android:id="@+id/widget_title"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Porta-Thoughty"
        android:textColor="#FFFFFF"
        android:textSize="14sp"
        android:textStyle="bold"
        android:paddingBottom="8dp" />

    <ImageButton
        android:id="@+id/widget_button"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:minWidth="56dp"
        android:minHeight="56dp"
        android:src="@drawable/ic_mic_black_24dp"
        android:background="?android:attr/selectableItemBackgroundBorderless"
        android:contentDescription="Record voice note"
        android:scaleType="centerInside"
        android:tint="#FFFFFF" />

    <TextView
        android:id="@+id/widget_project_name"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Inbox"
        android:textColor="#E0E0E0"
        android:textSize="12sp"
        android:paddingTop="8dp" />
</LinearLayout>
```

**Step 3: Update 1x1 widget to use mascot as button**

Update `android/app/src/main/res/layout/record_widget.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_background"
    android:padding="8dp">

    <ImageButton
        android:id="@+id/widget_button"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:src="@drawable/mascot_icon"
        android:background="?android:attr/selectableItemBackgroundBorderless"
        android:contentDescription="Record voice note with Porta-Thoughty"
        android:scaleType="fitCenter" />
</FrameLayout>
```

**Step 4: Update RecordWidgetProvider to change mascot on recording state**

Open `android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordWidgetProvider.kt` and update the icon logic:

Find this section:
```kotlin
// Set button icon based on recording state
val iconRes = if (isRecording) {
    R.drawable.ic_stop_black_24dp
} else {
    R.drawable.ic_mic_black_24dp
}
views.setImageViewResource(R.id.widget_button, iconRes)
```

Replace with:
```kotlin
// Set button icon based on recording state
val iconRes = if (isRecording) {
    R.drawable.ic_stop_black_24dp
} else {
    // Use mascot for 1x1, mic icon for 2x2
    if (is2x2) R.drawable.ic_mic_black_24dp else R.drawable.mascot_icon
}
views.setImageViewResource(R.id.widget_button, iconRes)
```

**Step 5: Commit mascot additions**

```bash
git add android/app/src/main/res/drawable/mascot_icon.xml android/app/src/main/res/layout/record_widget.xml android/app/src/main/res/layout/record_widget_2x2.xml android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordWidgetProvider.kt
git commit -m "feat: add mascot icon to widgets"
```

---

## Task 8: Testing and Documentation

**Files:**
- Create: `docs/widget-usage.md`

**Step 1: Create user documentation**

Create file `docs/widget-usage.md`:

```markdown
# Home Screen Widget Usage

## Overview
Porta-Thoughty provides home screen widgets (1x1 and 2x2) for quick voice recording without opening the app.

## Features
- **Project Selection**: Choose which project to record notes to during widget setup
- **Background Recording**: Record voice notes with app closed
- **Silence Detection**: Stops recording after 8 seconds of silence
- **Manual Stop**: Tap widget again while recording to stop
- **Max Duration**: Automatically stops after 2 minutes
- **Auto-Transcription**: Notes are transcribed and added to queue automatically

## Setup

### Adding Widget to Home Screen
1. Long-press on home screen
2. Select "Widgets"
3. Find "Porta-Thoughty" widgets
4. Choose 1x1 (simple) or 2x2 (detailed) widget
5. Drag to home screen
6. Select project from dropdown in configuration screen
7. Tap "Add Widget"

### Widget Sizes

**1x1 Widget (Minimal)**
- Shows mascot/logo icon
- Tap to start/stop recording
- Best for quick access

**2x2 Widget (Detailed)**
- Shows mascot, app name, and project name
- Larger button for easier tapping
- Displays recording project

## Using the Widget

### Starting Recording
1. Tap the widget
2. Grant microphone permission if prompted
3. Notification appears: "Recording to [Project Name]"
4. Speak your thought

### Stopping Recording
Recording stops automatically when:
- **Silence**: 8 seconds of no speech detected
- **Manual**: Tap the widget again
- **Timeout**: 2 minutes maximum duration reached

### After Recording
- Note is transcribed using device speech recognition
- Transcription is saved to your selected project's queue
- Open the app to view, edit, or process the note

## Troubleshooting

**Widget not recording:**
- Check microphone permission in Settings > Apps > Porta-Thoughty
- Ensure notification permission is granted (Android 13+)
- Restart device if widget appears unresponsive

**Transcription not appearing in app:**
- Open the app to trigger sync
- Check the correct project is selected
- Verify storage permissions

**Widget shows wrong state:**
- Remove and re-add the widget
- Force close the app and reopen

## Technical Notes
- Requires Android 8.0 (API 26) or higher
- Uses device's built-in speech recognition
- Recording happens in foreground service (notification required)
- Works offline (transcription quality depends on device)
```

**Step 2: Create testing checklist**

Create file `docs/widget-testing-checklist.md`:

```markdown
# Widget Testing Checklist

## Pre-Testing Setup
- [ ] Run `flutter clean && flutter pub get`
- [ ] Build APK: `flutter build apk`
- [ ] Install on physical Android device (emulator speech recognition limited)
- [ ] Grant microphone permission
- [ ] Grant notification permission (Android 13+)
- [ ] Create at least 2 projects in the app (e.g., "Inbox", "Work")

## Widget Configuration Testing
- [ ] Long-press home screen and add 1x1 widget
- [ ] Configuration screen appears
- [ ] Projects list populates correctly
- [ ] Select "Work" project
- [ ] Tap "Add Widget" - widget appears on home screen
- [ ] Long-press home screen and add 2x2 widget
- [ ] Select "Inbox" project
- [ ] Both widgets are now on home screen

## 1x1 Widget Testing
- [ ] Widget shows mascot icon
- [ ] Widget background is blue (#0D7BCE)
- [ ] Tap widget - foreground service starts
- [ ] Notification appears: "Recording to Work"
- [ ] Widget icon changes to stop icon
- [ ] Speak: "Test recording from 1x1 widget"
- [ ] Wait 8 seconds of silence
- [ ] Recording stops automatically
- [ ] Widget icon changes back to mascot
- [ ] Notification disappears
- [ ] Open app
- [ ] Navigate to Queue screen
- [ ] Switch to "Work" project
- [ ] Note appears: "Test recording from 1x1 widget"

## 2x2 Widget Testing
- [ ] Widget shows mascot, "Porta-Thoughty" title, and "Inbox" project name
- [ ] Tap widget - recording starts
- [ ] Notification: "Recording to Inbox"
- [ ] Speak: "This is a longer test recording to verify that the transcription works correctly with multiple sentences"
- [ ] Tap widget again (manual stop)
- [ ] Recording stops immediately
- [ ] Widget returns to normal state
- [ ] Open app and verify note in "Inbox" project queue

## Stop Condition Testing

**Silence Timeout (8 seconds):**
- [ ] Start recording via widget
- [ ] Speak for 3 seconds
- [ ] Stay silent for 8+ seconds
- [ ] Recording stops automatically
- [ ] Note appears in queue

**Manual Stop:**
- [ ] Start recording via widget
- [ ] Speak for 5 seconds
- [ ] Tap widget again
- [ ] Recording stops immediately
- [ ] Note appears in queue

**Max Duration (2 minutes):**
- [ ] Start recording via widget
- [ ] Speak intermittently (every 7 seconds) for 2 minutes
- [ ] Recording stops at exactly 2 minutes
- [ ] Full transcription saved (up to 2 min of speech)

## Edge Cases

**App Closed:**
- [ ] Force close Porta-Thoughty app (swipe from recent apps)
- [ ] Tap widget
- [ ] Recording works without opening app
- [ ] Open app after recording
- [ ] Note appears in queue

**Multiple Recordings:**
- [ ] Record via widget (Recording A)
- [ ] Wait for transcription
- [ ] Immediately record again (Recording B)
- [ ] Both notes appear in queue

**Project Switching:**
- [ ] Add 2 widgets with different projects
- [ ] Record via Widget 1 (Project A)
- [ ] Record via Widget 2 (Project B)
- [ ] Open app
- [ ] Verify notes in correct projects

**Permission Denial:**
- [ ] Remove microphone permission from Settings
- [ ] Tap widget
- [ ] Error handled gracefully (no crash)
- [ ] Grant permission
- [ ] Widget works again

**Empty Speech:**
- [ ] Start recording via widget
- [ ] Stay completely silent for 8+ seconds
- [ ] Recording stops
- [ ] No empty note created in queue

## UI/Visual Testing
- [ ] Widget icons render correctly (mascot, mic, stop)
- [ ] Widget background has rounded corners
- [ ] 2x2 widget text is readable
- [ ] Widget resizes correctly when dragged to different grid sizes
- [ ] Notification shows correct icon and text
- [ ] Stop action in notification works

## Performance Testing
- [ ] Widget responds to tap within 1 second
- [ ] Recording starts within 2 seconds of tap
- [ ] Transcription completes within 5 seconds of recording stop
- [ ] No excessive battery drain during idle widget
- [ ] App sync is fast when opening after widget recording

## Cleanup Testing
- [ ] Remove widget from home screen
- [ ] Verify no orphaned services running
- [ ] Verify SharedPreferences cleaned up (widget_prefs)
- [ ] Re-add widget - configuration works correctly

## Final Verification
- [ ] All tests passed
- [ ] No crashes observed
- [ ] Transcription accuracy is acceptable
- [ ] Widget remains responsive after multiple recordings
- [ ] App and widget state stay synchronized
```

**Step 3: Update CLAUDE.md with widget information**

Open `CLAUDE.md` and add a new section at the end:

```markdown

## Home Screen Widget

### Widget Types
- **1x1 Widget**: Minimal design with mascot icon
- **2x2 Widget**: Shows mascot, app name, mic button, and project name

### Widget Configuration
- User selects recording project during widget setup
- Configuration stored in SharedPreferences (`widget_prefs`)
- Project names cached to `projects_cache` SharedPreferences key

### Recording Flow (Widget)
1. User taps widget
2. `RecordWidgetProvider` receives tap broadcast
3. Starts `RecordingForegroundService` with project info
4. Service shows notification and starts Android SpeechRecognizer
5. Recording stops on: silence (8s), manual tap, or 2min timeout
6. Service saves transcription to `widget_recordings` SharedPreferences
7. Service launches `MainActivity` with `SAVE_TRANSCRIPTION` action
8. MainActivity calls `saveWidgetTranscription` via MethodChannel
9. Flutter saves note to database and updates UI

### Widget State Management
- Widget icon changes based on recording state (mic ↔ stop)
- State synchronized via `updateWidget()` method calls from service
- Widget uses `PendingIntent.FLAG_MUTABLE` for dynamic state updates

### Key Files
- Widget Provider: `android/.../widget/RecordWidgetProvider.kt`
- Foreground Service: `android/.../widget/RecordingForegroundService.kt`
- Configuration Activity: `android/.../widget/WidgetConfigActivity.kt`
- Widget Layouts: `android/app/src/main/res/layout/record_widget*.xml`
- Flutter Integration: `lib/state/app_state.dart` (`saveWidgetTranscription`)

### Testing Widget
See `docs/widget-testing-checklist.md` for comprehensive test plan.
```

**Step 4: Commit documentation**

```bash
git add docs/widget-usage.md docs/widget-testing-checklist.md CLAUDE.md
git commit -m "docs: add widget usage guide and testing checklist"
```

**Step 5: Build and test on device**

Run: `flutter build apk`
Expected: "Built build/app/outputs/flutter-apk/app-release.apk"

**Step 6: Manual testing**

Follow the testing checklist in `docs/widget-testing-checklist.md` to verify all functionality works correctly on a physical Android device.

---

## Task 9: Final Polish and Bug Fixes

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordingForegroundService.kt`

**Step 1: Add notification channel importance update**

The current notification implementation may not show properly on all devices. Update the notification channel creation in `RecordingForegroundService.kt`:

Find the `createNotificationChannel()` method and update it:

```kotlin
private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Recording Service",
            NotificationManager.IMPORTANCE_LOW  // Changed from IMPORTANCE_DEFAULT
        ).apply {
            description = "Shows when recording voice notes"
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
        }
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }
}
```

**Step 2: Add permission request for Android 13+ notifications**

Create a method in `RecordingForegroundService.kt` to check notification permission:

Add this method before `startRecording()`:

```kotlin
private fun hasNotificationPermission(): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
    } else {
        true
    }
}
```

Update `onStartCommand` to check permission:

```kotlin
override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
        ACTION_START_RECORDING -> {
            if (!hasNotificationPermission()) {
                stopSelf()
                return START_NOT_STICKY
            }
            widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            projectId = intent.getStringExtra(EXTRA_PROJECT_ID) ?: ""
            projectName = intent.getStringExtra(EXTRA_PROJECT_NAME) ?: "Inbox"
            startRecording()
        }
        ACTION_STOP_RECORDING -> {
            stopRecording()
        }
    }
    return START_NOT_STICKY
}
```

**Step 3: Add error handling for speech recognition failures**

Update the `onError` method in the `RecognitionListener` inside `startSpeechRecognition()`:

```kotlin
override fun onError(error: Int) {
    val errorMessage = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
        SpeechRecognizer.ERROR_CLIENT -> "Client error"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission denied"
        SpeechRecognizer.ERROR_NETWORK -> "Network error"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
        SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
        SpeechRecognizer.ERROR_SERVER -> "Server error"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout"
        else -> "Unknown error: $error"
    }

    // Log error
    android.util.Log.e("RecordingService", "Speech recognition error: $errorMessage")

    // Stop recording on error
    stopRecording()
}
```

**Step 4: Add wake lock to prevent service from being killed**

Add these properties at the top of `RecordingForegroundService` class:

```kotlin
import android.os.PowerManager  // Add to imports

class RecordingForegroundService : Service() {

    private var speechRecognizer: SpeechRecognizer? = null
    private var widgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID
    private var projectId: String = ""
    private var projectName: String = "Inbox"
    private var maxDurationTimer: TimerTask? = null
    private var transcribedText: String = ""
    private var wakeLock: PowerManager.WakeLock? = null  // ADD THIS

    // ... rest of class
}
```

Update `startRecording()` to acquire wake lock:

```kotlin
private fun startRecording() {
    // Acquire wake lock
    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
    wakeLock = powerManager.newWakeLock(
        PowerManager.PARTIAL_WAKE_LOCK,
        "PortaThoughty::RecordingWakeLock"
    )
    wakeLock?.acquire(MAX_RECORDING_DURATION_MS)

    // Create stop intent
    // ... rest of existing code
}
```

Update `onDestroy()` to release wake lock:

```kotlin
override fun onDestroy() {
    super.onDestroy()
    speechRecognizer?.destroy()
    maxDurationTimer?.cancel()
    wakeLock?.release()  // ADD THIS
}
```

**Step 5: Commit bug fixes and polish**

```bash
git add android/app/src/main/kotlin/com/example/porta_thoughty/widget/RecordingForegroundService.kt
git commit -m "fix: improve notification handling, permissions, and error handling"
```

---

## Task 10: Create Migration Guide for Existing Users

**Files:**
- Create: `docs/widget-migration.md`

**Step 1: Create migration guide**

Create file `docs/widget-migration.md`:

```markdown
# Widget Feature Migration Guide

## For Existing Users

If you're upgrading from a version without widget support, follow this guide to enable the new home screen widget feature.

## What's New

### Version with Widget Support
- Home screen widgets (1x1 and 2x2 sizes)
- Background voice recording without opening app
- Project selection during widget setup
- Automatic transcription to queue

## Installation

### For Developers
1. Pull latest changes: `git pull origin main`
2. Clean project: `flutter clean`
3. Install dependencies: `flutter pub get`
4. Rebuild app: `flutter build apk` (or `flutter run` for testing)
5. Uninstall old version from device (to ensure permissions update)
6. Install new APK

### For Users
1. Update app from app store (when released)
2. Open app once to grant new permissions
3. Add widget to home screen (see `docs/widget-usage.md`)

## Permissions

The widget requires these new permissions:
- **POST_NOTIFICATIONS**: Show recording notification (Android 13+)
- **WAKE_LOCK**: Keep service alive during recording
- **MODIFY_AUDIO_SETTINGS**: Adjust microphone settings

These are requested automatically on first widget use.

## Breaking Changes

### None
- All existing features work as before
- Database schema unchanged
- App state management unchanged
- Widget is an additive feature

## Configuration

### Default Project for Widget
When adding your first widget, you'll be prompted to select a project. This choice is saved per widget, so you can have multiple widgets recording to different projects.

### Updating Widget Project
To change which project a widget records to:
1. Long-press the widget
2. Remove it
3. Add a new widget
4. Select the desired project

**Note**: Future update may add in-widget project switching.

## Troubleshooting

### Widget not appearing in widget list
- Ensure app is installed (not just cached APK)
- Restart device
- Check Android version (requires 8.0+)

### Recording permission errors
- Go to Settings > Apps > Porta-Thoughty > Permissions
- Ensure Microphone and Notifications are enabled
- If disabled, enable and try recording again

### Transcriptions not syncing
- Open the app to trigger sync
- Check that device has speech recognition enabled
- Verify internet connection (for cloud speech models)

## Feature Comparison

| Feature | In-App Recording | Widget Recording |
|---------|------------------|------------------|
| Project Selection | Yes (manual switch) | Yes (per-widget config) |
| Transcription | Real-time | Post-recording |
| Silence Detection | 8 seconds | 8 seconds |
| Max Duration | 2 minutes | 2 minutes |
| App Must Be Open | Yes | No |
| Visual Feedback | Live waveform | Notification |
| Manual Stop | Button | Tap widget |

## Rollback

If you encounter issues with the widget feature and need to roll back:

1. Uninstall current version
2. Install previous APK (without widget support)
3. Your notes and projects are preserved (database unchanged)
4. Report issue at: [GitHub Issues](https://github.com/yourusername/porta-thoughty/issues)

## Known Limitations

### Current Version
- Android only (iOS widgets have different architecture)
- Cannot update widget project without removing and re-adding
- Recording requires foreground notification (Android limitation)
- Transcription quality depends on device speech recognition

### Future Enhancements
- iOS widget support
- In-widget project switching
- Custom widget themes
- Longer recording durations option
```

**Step 2: Add to main README if exists**

If there's a `README.md` in the root directory, add a section:

```markdown
## Features

- **Voice Recording**: Capture thoughts via speech-to-text
- **Text Notes**: Quick text input for ideas
- **Image OCR**: Extract text from images (future)
- **Queue Management**: Organize notes before processing
- **Markdown Export**: Generate organized documents
- **Home Screen Widget**: Record voice notes without opening app ⭐ NEW

### Home Screen Widget
- Add 1x1 or 2x2 widget to home screen
- Choose recording project during setup
- Tap to start/stop recording
- Automatic transcription to queue
- Works with app closed

See [Widget Usage Guide](docs/widget-usage.md) for details.
```

**Step 3: Commit migration guide**

```bash
git add docs/widget-migration.md README.md
git commit -m "docs: add widget migration guide for existing users"
```

---

## Final Verification

### Manual Testing Checklist
Run through the complete testing checklist in `docs/widget-testing-checklist.md` on a physical Android device.

### Expected Behavior
- [ ] 1x1 and 2x2 widgets add successfully
- [ ] Widget configuration shows projects
- [ ] Recording starts from widget tap
- [ ] Notification displays during recording
- [ ] Recording stops on silence (8s), manual tap, or 2min timeout
- [ ] Transcription appears in Flutter app queue
- [ ] Notes save to correct project
- [ ] Widget icon updates (mic ↔ stop)
- [ ] No crashes or permission errors

### Build Commands
```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build APK
flutter build apk

# Or run on connected device
flutter run
```

### Common Issues and Solutions

**Widget not showing projects in configuration:**
- Open Flutter app first to cache projects
- Check `shared_preferences` is installed
- Verify `_cacheProjectsForWidget()` is called in `app_state.dart`

**Recording not starting:**
- Check microphone permission granted
- Verify foreground service declared in AndroidManifest.xml
- Check Android version >= 8.0

**Transcription not appearing in app:**
- Open app to trigger MethodChannel handler
- Check `MainActivity.onNewIntent()` handles `SAVE_TRANSCRIPTION`
- Verify `saveWidgetTranscription()` method exists in `app_state.dart`

**Widget stuck in recording state:**
- Force stop app and recording service
- Remove and re-add widget
- Check service is properly destroyed in `onDestroy()`

---

## Implementation Complete

This plan provides a complete implementation of home screen widgets (1x1 and 2x2) with:

✅ Project selection during widget setup
✅ Background recording via foreground service
✅ Silence detection (8 seconds)
✅ Manual stop (tap widget again)
✅ Max duration (2 minutes)
✅ Automatic transcription to queue
✅ Mascot/logo integration
✅ Comprehensive documentation
✅ Testing checklist
✅ Error handling and polish

**Total Tasks**: 10
**Estimated Implementation Time**: 6-8 hours
**Files Created**: 12+
**Files Modified**: 8+

---

## Next Steps After Implementation

1. **Test on Multiple Devices**: Android 8, 10, 12, 13, 14
2. **User Testing**: Get feedback on widget UX
3. **Performance Monitoring**: Check battery drain and memory usage
4. **Documentation Updates**: Add screenshots to usage guide
5. **iOS Widget**: Consider implementing iOS widgets with limitations
6. **Analytics**: Track widget usage vs in-app recording
7. **Iteration**: Add features like in-widget project switching

---

**Commit Summary**:
```bash
git log --oneline
# Should show commits:
# - feat: add shared_preferences and recording service permissions
# - feat: add widget configuration activity for project selection
# - feat: create foreground service for background voice recording
# - feat: update widget provider with 1x1 and 2x2 layouts
# - feat: integrate widget transcriptions with Flutter app state
# - feat: cache projects to SharedPreferences for widget access
# - feat: add mascot icon to widgets
# - docs: add widget usage guide and testing checklist
# - fix: improve notification handling, permissions, and error handling
# - docs: add widget migration guide for existing users
```
