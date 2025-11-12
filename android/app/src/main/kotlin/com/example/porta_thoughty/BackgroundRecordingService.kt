package com.example.porta_thoughty

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.*

class BackgroundRecordingService : Service() {
    private var speechRecognizer: SpeechRecognizer? = null
    private var isRecording = false
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "porta_thoughty_recording"

    companion object {
        const val ACTION_START_RECORDING = "START_RECORDING"
        const val ACTION_STOP_RECORDING = "STOP_RECORDING"
        private const val PREFS_NAME = "porta_thoughty_pending_notes"
        private const val KEY_PENDING_NOTES = "pending_notes"

        fun savePendingNote(context: Context, transcription: String, projectId: String = "inbox") {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingNotes = prefs.getString(KEY_PENDING_NOTES, "[]") ?: "[]"
            val notesArray = JSONArray(existingNotes)

            val note = JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("transcription", transcription)
                put("projectId", projectId)
                put("timestamp", System.currentTimeMillis())
                put("type", "voice")
            }

            notesArray.put(note)
            prefs.edit().putString(KEY_PENDING_NOTES, notesArray.toString()).apply()
            println("Saved pending note: $transcription")
        }

        fun getPendingNotes(context: Context): List<Map<String, Any>> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val notesJson = prefs.getString(KEY_PENDING_NOTES, "[]") ?: "[]"
            val notesArray = JSONArray(notesJson)
            val notes = mutableListOf<Map<String, Any>>()

            for (i in 0 until notesArray.length()) {
                val noteJson = notesArray.getJSONObject(i)
                notes.add(mapOf(
                    "id" to noteJson.getString("id"),
                    "transcription" to noteJson.getString("transcription"),
                    "projectId" to noteJson.optString("projectId", "inbox"),
                    "timestamp" to noteJson.getLong("timestamp"),
                    "type" to noteJson.optString("type", "voice")
                ))
            }

            return notes
        }

        fun clearPendingNotes(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_PENDING_NOTES, "[]").apply()
            println("Cleared pending notes")
        }
    }

    override fun onCreate() {
        super.onCreate()
        android.util.Log.d("BackgroundRecordingService", "onCreate()")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("BackgroundRecordingService", "onStartCommand: action=${intent?.action}")
        when (intent?.action) {
            ACTION_START_RECORDING -> startRecording()
            ACTION_STOP_RECORDING -> stopRecording()
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
                description = "Porta-Thoughty voice recording"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(isRecording: Boolean): Notification {
        val contentTitle = if (isRecording) "Recording..." else "Processing..."
        val contentText = if (isRecording) "Tap to stop recording" else "Transcribing your note"

        val stopIntent = Intent(this, BackgroundRecordingService::class.java).apply {
            action = ACTION_STOP_RECORDING
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(isRecording)
            .apply {
                if (isRecording) {
                    addAction(
                        android.R.drawable.ic_media_pause,
                        "Stop",
                        stopPendingIntent
                    )
                }
            }
            .build()
    }

    private fun startRecording() {
        android.util.Log.d("BackgroundRecordingService", "startRecording() called, isRecording=$isRecording")

        if (isRecording) {
            android.util.Log.w("BackgroundRecordingService", "Already recording, ignoring start request")
            return
        }

        // Check if speech recognition is available
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            android.util.Log.e("BackgroundRecordingService", "Speech recognition not available on this device")
            savePendingNote(this, "[Error: Speech recognition not available on this device]", "inbox")
            stopSelf()
            return
        }

        android.util.Log.d("BackgroundRecordingService", "Starting foreground service with notification")
        isRecording = true

        // For Android 14+ (API 34+), specify the foreground service type
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                createNotification(true),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, createNotification(true))
        }

        updateWidget(true)

        android.util.Log.d("BackgroundRecordingService", "Creating SpeechRecognizer")
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    println("Ready for speech")
                }

                override fun onBeginningOfSpeech() {
                    println("Speech started")
                }

                override fun onRmsChanged(rmsdB: Float) {}

                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    println("Speech ended")
                }

                override fun onError(error: Int) {
                    println("Speech recognition error: $error")
                    val errorMessage = when (error) {
                        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                        SpeechRecognizer.ERROR_CLIENT -> "Client error"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                        SpeechRecognizer.ERROR_NETWORK -> "Network error"
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                        SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
                        SpeechRecognizer.ERROR_SERVER -> "Server error"
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
                        else -> "Unknown error"
                    }

                    // Only save error notes for actual errors, not timeouts
                    if (error != SpeechRecognizer.ERROR_SPEECH_TIMEOUT &&
                        error != SpeechRecognizer.ERROR_NO_MATCH) {
                        savePendingNote(
                            this@BackgroundRecordingService,
                            "[Recording error: $errorMessage]",
                            "inbox"
                        )
                    }

                    stopRecording()
                }

                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val transcription = matches?.firstOrNull() ?: ""

                    if (transcription.isNotEmpty()) {
                        println("Transcription: $transcription")
                        savePendingNote(this@BackgroundRecordingService, transcription, "inbox")
                    }

                    stopRecording()
                }

                override fun onPartialResults(partialResults: Bundle?) {}

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 8000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 8000L)
            }

            android.util.Log.d("BackgroundRecordingService", "Starting speech recognition listener")
            try {
                startListening(intent)
                android.util.Log.d("BackgroundRecordingService", "Speech recognition started successfully")
            } catch (e: Exception) {
                android.util.Log.e("BackgroundRecordingService", "Failed to start listening", e)
                savePendingNote(this@BackgroundRecordingService, "[Error: Failed to start recording - ${e.message}]", "inbox")
                stopRecording()
            }
        }
    }

    private fun stopRecording() {
        android.util.Log.d("BackgroundRecordingService", "stopRecording() called, isRecording=$isRecording")
        if (!isRecording) return

        isRecording = false
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null

        updateWidget(false)
        stopForeground(true)
        stopSelf()
        android.util.Log.d("BackgroundRecordingService", "Service stopped")
    }

    private fun updateWidget(isRecording: Boolean) {
        val intent = Intent(this, com.example.porta_thoughty.widget.RecordWidgetProvider::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra("isRecording", isRecording)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        stopRecording()
    }
}
