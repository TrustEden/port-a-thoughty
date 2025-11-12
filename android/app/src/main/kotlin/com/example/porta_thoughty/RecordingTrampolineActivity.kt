package com.example.porta_thoughty

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log

/**
 * Transparent trampoline activity to start the recording service.
 * This is necessary for Android 14+ where starting foreground services
 * from the background (even from widgets) is restricted.
 *
 * Activities can start foreground services, so this activity acts as
 * a bridge between the widget and the service.
 */
class RecordingTrampolineActivity : Activity() {

    companion object {
        const val EXTRA_IS_RECORDING = "isRecording"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("RecordingTrampoline", "onCreate: Starting service")

        val isRecording = intent.getBooleanExtra(EXTRA_IS_RECORDING, false)

        val serviceIntent = Intent(this, BackgroundRecordingService::class.java).apply {
            action = if (isRecording) {
                BackgroundRecordingService.ACTION_STOP_RECORDING
            } else {
                BackgroundRecordingService.ACTION_START_RECORDING
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d("RecordingTrampoline", "Starting foreground service")
                startForegroundService(serviceIntent)
            } else {
                Log.d("RecordingTrampoline", "Starting service")
                startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e("RecordingTrampoline", "Failed to start service", e)
        }

        // Immediately finish the activity so it doesn't show
        finish()
    }
}
