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

        // Launch recording activity directly from widget
        // Android 15+ requires visible activity for microphone access ("while-in-use")
        // The activity performs recording, saves offline, and auto-closes
        val activityIntent = Intent(context, com.example.porta_thoughty.RecordingTrampolineActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        views.setOnClickPendingIntent(R.id.record_button, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}