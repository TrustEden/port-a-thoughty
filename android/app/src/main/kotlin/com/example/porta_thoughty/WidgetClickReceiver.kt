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

            // Start the trampoline activity which will start the service
            // This is necessary for Android 14+ FGS restrictions
            val activityIntent = Intent(context, RecordingTrampolineActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
                putExtra(RecordingTrampolineActivity.EXTRA_IS_RECORDING, isRecording)
            }

            try {
                Log.d("WidgetClickReceiver", "Starting trampoline activity")
                context.startActivity(activityIntent)
            } catch (e: Exception) {
                Log.e("WidgetClickReceiver", "Failed to start activity", e)
            }
        }
    }
}
