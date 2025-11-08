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
        val views = RemoteViews(context.packageName, R.layout.record_widget)

        // Set the appropriate icon based on recording state
        if (isRecording) {
            views.setImageViewResource(R.id.record_button, R.drawable.stoprecording)
        } else {
            views.setImageViewResource(R.id.record_button, R.drawable.capture)
        }

        // Set up click handler to open app and start recording
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                data = Uri.parse("homeWidgetExample://home_widget/record")
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.record_button, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}