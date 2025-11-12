package com.example.porta_thoughty.widget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
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

class RecordingForegroundService : Service() {

    private var speechRecognizer: SpeechRecognizer? = null
    private var transcribedText: String = ""
    private var maxDurationTimer: Timer? = null

    companion object {
        const val CHANNEL_ID = "recording_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START_RECORDING = "com.example.porta_thoughty.START_RECORDING"
        const val ACTION_STOP_RECORDING = "com.example.porta_thoughty.STOP_RECORDING"
        const val MAX_RECORDING_DURATION_MS = 120000L // 2 minutes
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_RECORDING -> {
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
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
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
            .setContentTitle("Recording voice note")
            .setContentText("Tap to stop recording")
            .setSmallIcon(R.drawable.capture)
            .setOngoing(true)
            .addAction(R.drawable.stoprecording, "Stop", stopPendingIntent)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        // Initialize speech recognizer
        startSpeechRecognition()

        // Set max duration timer (2 minutes)
        maxDurationTimer = Timer().schedule(
            object : TimerTask() {
                override fun run() {
                    stopRecording()
                }
            },
            MAX_RECORDING_DURATION_MS
        )
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
                // Volume changed
            }

            override fun onBufferReceived(buffer: ByteArray?) {
                // Not used
            }

            override fun onEndOfSpeech() {
                // User stopped speaking (silence detected)
                stopRecording()
            }

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

                android.util.Log.e("RecordingService", "Speech recognition error: $errorMessage")
                stopRecording()
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
                // Partial results - update transcribed text
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

        // Stop foreground service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
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
            .putLong("pending_timestamp", timestamp)
            .apply()

        // Notify Flutter app if it's running
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "com.example.porta_thoughty.SAVE_TRANSCRIPTION"
            putExtra("transcription", transcribedText)
            putExtra("timestamp", timestamp)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        // Only try to notify if app might be running, otherwise it will sync on next open
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // App not running, that's fine - will sync on next open
            android.util.Log.d("RecordingService", "App not running, recording saved for later sync")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
        maxDurationTimer?.cancel()
    }
}
