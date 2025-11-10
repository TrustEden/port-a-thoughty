package com.example.porta_thoughty

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.ComponentName
import android.os.Bundle
import android.os.Build
import android.app.PictureInPictureParams
import android.util.Rational
import com.example.porta_thoughty.widget.RecordWidgetProvider

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.porta_thoughty/widget"
    private val PIP_CHANNEL = "com.porta_thoughty/pip"
    private lateinit var methodChannel: MethodChannel
    private lateinit var pipChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Widget channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val isRecording = call.argument<Boolean>("isRecording") ?: false
                updateRecordWidget(this, isRecording)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // PiP channel
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipSupported" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                }
                "enterPipMode" -> {
                    val success = enterPipMode()
                    result.success(success)
                }
                "isInPipMode" -> {
                    result.success(isInPictureInPictureMode)
                }
                else -> {
                    result.notImplemented()
                }
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

    private fun enterPipMode(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(3, 4)) // Portrait-ish ratio for button
                    .build()
                enterPictureInPictureMode(params)
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Notify Flutter about PiP state change if needed
            pipChannel.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
        }
    }

    override fun onUserLeaveHint() {
        // Don't call super to prevent automatic PiP on user leaving
        // We handle PiP entry from Flutter side
    }
}