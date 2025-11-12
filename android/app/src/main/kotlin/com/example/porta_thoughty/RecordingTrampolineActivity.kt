package com.example.porta_thoughty

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Window
import android.view.WindowManager

/**
 * Trampoline activity to start the recording service.
 *
 * CRITICAL: For microphone-type foreground services, Android requires
 * the activity to be ACTUALLY VISIBLE (not just transparent) due to
 * "while-in-use" permission restrictions. This activity shows briefly
 * (500ms) to satisfy that requirement.
 *
 * From Android docs: "You cannot create a microphone foreground service
 * while your app is in the background, even if the app falls into one
 * of the exemptions from background start restrictions."
 */
class RecordingTrampolineActivity : Activity() {

    companion object {
        const val EXTRA_IS_RECORDING = "isRecording"
        const val VISIBILITY_DELAY_MS = 1000L // Must be visible for while-in-use permission
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set actual content view to be FULLY visible (required for microphone while-in-use)
        setContentView(R.layout.activity_recording_trampoline)

        Log.d("RecordingTrampoline", "onCreate: Starting service with VISIBLE activity")

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
                Log.d("RecordingTrampoline", "Starting foreground service while fully visible")
                startForegroundService(serviceIntent)
            } else {
                Log.d("RecordingTrampoline", "Starting service")
                startService(serviceIntent)
            }

            // Keep activity visible for 1 second to establish "foreground" status
            // This satisfies Android's while-in-use requirement for microphone services
            Handler(Looper.getMainLooper()).postDelayed({
                Log.d("RecordingTrampoline", "Finishing activity after visibility period")
                finish()
            }, VISIBILITY_DELAY_MS)

        } catch (e: Exception) {
            Log.e("RecordingTrampoline", "Failed to start service", e)
            finish()
        }
    }
}
