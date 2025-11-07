package com.example.porta_thoughty.widget

import com.example.porta_thoughty.R
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.example.porta_thoughty.MainActivity // Import your MainActivity
import android.content.ComponentName // Added this import

class RecordWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.record_widget).apply {
                // Open App on Widget Click
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java).apply {
                        data = Uri.parse("homeWidgetExample://home_widget/record")
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.record_button, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisAppWidget = ComponentName(context, RecordWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)

        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.record_widget)
            val isRecording = intent.extras?.getString("isRecording")?.toBoolean() ?: false

            if (isRecording) {
                views.setImageViewResource(R.id.record_button, R.drawable.ic_stop_black_24dp)
            } else {
                views.setImageViewResource(R.id.record_button, R.drawable.ic_mic_black_24dp)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}