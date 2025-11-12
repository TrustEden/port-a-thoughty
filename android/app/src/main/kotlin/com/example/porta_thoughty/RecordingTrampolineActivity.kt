package com.example.porta_thoughty

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import android.widget.TextView

/**
 * Recording activity that handles voice capture while visible.
 *
 * This approach satisfies Android 15's "while-in-use" requirement for
 * microphone access - the activity must be visible during recording.
 *
 * Flow:
 * 1. Widget tap → Activity opens
 * 2. Activity shows "Recording..." UI and starts speech recognition
 * 3. User speaks, then stops (8 sec silence)
 * 4. Note is saved to database
 * 5. Activity auto-closes
 */
class RecordingTrampolineActivity : Activity() {

    private var speechRecognizer: SpeechRecognizer? = null
    private var statusText: TextView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_recording_trampoline)

        statusText = findViewById(R.id.recording_status)

        Log.d("RecordingActivity", "onCreate: Starting recording")
        startRecording()
    }

    private fun startRecording() {
        // Check if speech recognition is available
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.e("RecordingActivity", "Speech recognition not available")
            updateStatus("Speech recognition not available")
            BackgroundRecordingService.savePendingNote(
                this,
                "[Error: Speech recognition not available on this device]",
                "inbox"
            )
            finishWithDelay(2000)
            return
        }

        updateStatus("Listening...")

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    Log.d("RecordingActivity", "Ready for speech")
                    runOnUiThread { updateStatus("Listening...") }
                }

                override fun onBeginningOfSpeech() {
                    Log.d("RecordingActivity", "Speech started")
                    runOnUiThread { updateStatus("Recording...") }
                }

                override fun onRmsChanged(rmsdB: Float) {}

                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    Log.d("RecordingActivity", "Speech ended")
                    runOnUiThread { updateStatus("Processing...") }
                }

                override fun onError(error: Int) {
                    Log.e("RecordingActivity", "Speech recognition error: $error")
                    val errorMessage = getErrorMessage(error)
                    runOnUiThread { updateStatus(errorMessage) }

                    // Only save error notes for actual errors, not timeouts
                    if (error != SpeechRecognizer.ERROR_SPEECH_TIMEOUT &&
                        error != SpeechRecognizer.ERROR_NO_MATCH) {
                        BackgroundRecordingService.savePendingNote(
                            this@RecordingTrampolineActivity,
                            "[Recording error: $errorMessage]",
                            "inbox"
                        )
                    }

                    finishWithDelay(2000)
                }

                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val transcription = matches?.firstOrNull() ?: ""

                    if (transcription.isNotEmpty()) {
                        Log.d("RecordingActivity", "Transcription: $transcription")
                        runOnUiThread { updateStatus("Saved!") }
                        BackgroundRecordingService.savePendingNote(
                            this@RecordingTrampolineActivity,
                            transcription,
                            "inbox"
                        )
                    } else {
                        runOnUiThread { updateStatus("No speech detected") }
                    }

                    finishWithDelay(1000)
                }

                override fun onPartialResults(partialResults: Bundle?) {}

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 8000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 8000L)
            }

            try {
                startListening(intent)
                Log.d("RecordingActivity", "Speech recognition started")
            } catch (e: Exception) {
                Log.e("RecordingActivity", "Failed to start listening", e)
                runOnUiThread { updateStatus("Failed to start recording") }
                BackgroundRecordingService.savePendingNote(
                    this@RecordingTrampolineActivity,
                    "[Error: Failed to start recording - ${e.message}]",
                    "inbox"
                )
                finishWithDelay(2000)
            }
        }
    }

    private fun updateStatus(message: String) {
        statusText?.text = message
    }

    private fun getErrorMessage(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "Client error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK -> "Network error"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
            SpeechRecognizer.ERROR_SERVER -> "Server error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
            else -> "Unknown error"
        }
    }

    private fun finishWithDelay(delayMs: Long) {
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            finish()
        }, delayMs)
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
        speechRecognizer = null
        Log.d("RecordingActivity", "Activity destroyed")
    }
}
