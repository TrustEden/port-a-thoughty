package com.example.porta_thoughty

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.ComponentName
import android.os.Bundle // Import Bundle
import com.example.porta_thoughty.widget.RecordWidgetProvider

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.porta_thoughty/widget"
    private lateinit var methodChannel: MethodChannel // Declare methodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL) // Initialize methodChannel
        methodChannel.setMethodCallHandler {
            call, result ->
            if (call.method == "updateWidget") {
                val isRecording = call.argument<Boolean>("isRecording") ?: false
                updateRecordWidget(this, isRecording)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Pass initial intent data to Flutter
        if (intent?.data != null) {
            methodChannel.invokeMethod("handleWidgetClick", intent.data.toString())
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle subsequent intents that re-launch the activity
        if (intent.data != null) {
            methodChannel.invokeMethod("handleWidgetClick", intent.data.toString())
        }
    }

    private fun updateRecordWidget(context: Context, isRecording: Boolean) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, RecordWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        val updateIntent = Intent(context, RecordWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra("isRecording", isRecording)
        }
        // Send broadcast to update all instances of the widget
        updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        context.sendBroadcast(updateIntent)
    }
}