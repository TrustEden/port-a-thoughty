package com.example.porta_thoughty.widget

import com.example.porta_thoughty.R
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.example.porta_thoughty.MainActivity
import android.content.ComponentName
import com.example.porta_thoughty.WidgetClickReceiver
import android.util.Log

class RecordWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { appWidgetId ->
            updateWidget(context, appWidgetManager, appWidgetId, false)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        // Handle custom widget update from MainActivity
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE && intent.hasExtra("isRecording")) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context, RecordWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            val isRecording = intent.getBooleanExtra("isRecording", false)

            appWidgetIds.forEach { appWidgetId ->
                updateWidget(context, appWidgetManager, appWidgetId, isRecording)
            }
        }
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, isRecording: Boolean) {
        Log.d("RecordWidgetProvider", "updateWidget: isRecording=$isRecording")
        val views = RemoteViews(context.packageName, R.layout.record_widget)

        // Set the appropriate icon based on recording state
        if (isRecording) {
            views.setImageViewResource(R.id.record_button, R.drawable.stoprecording)
        } else {
            views.setImageViewResource(R.id.record_button, R.drawable.capture)
        }

        // CRITICAL: Start foreground service directly from widget
        // This uses the widget interaction exemption for Android 11+ microphone restrictions
        val serviceIntent = Intent(context, com.example.porta_thoughty.BackgroundRecordingService::class.java).apply {
            action = if (isRecording) {
                com.example.porta_thoughty.BackgroundRecordingService.ACTION_STOP_RECORDING
            } else {
                com.example.porta_thoughty.BackgroundRecordingService.ACTION_START_RECORDING
            }
        }

        // Use getForegroundService for Android 12+ (API 31+), otherwise getService
        val pendingIntent = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            PendingIntent.getForegroundService(
                context,
                0,
                serviceIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getService(
                context,
                0,
                serviceIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        views.setOnClickPendingIntent(R.id.record_button, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}