package com.example.porta_thoughty

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class WidgetClickReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_WIDGET_CLICK = "com.example.porta_thoughty.WIDGET_CLICK"
        const val EXTRA_IS_RECORDING = "isRecording"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("WidgetClickReceiver", "onReceive: ${intent.action}")

        if (intent.action == ACTION_WIDGET_CLICK) {
            val isRecording = intent.getBooleanExtra(EXTRA_IS_RECORDING, false)

            val serviceIntent = Intent(context, BackgroundRecordingService::class.java).apply {
                action = if (isRecording) {
                    BackgroundRecordingService.ACTION_STOP_RECORDING
                } else {
                    BackgroundRecordingService.ACTION_START_RECORDING
                }
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Log.d("WidgetClickReceiver", "Starting foreground service (API 26+)")
                    context.startForegroundService(serviceIntent)
                } else {
                    Log.d("WidgetClickReceiver", "Starting service (API < 26)")
                    context.startService(serviceIntent)
                }
            } catch (e: Exception) {
                Log.e("WidgetClickReceiver", "Failed to start service", e)
            }
        }
    }
}
