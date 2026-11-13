package com.gromhork.strive

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by the Health Connect permission flow.
class MainActivity : FlutterFragmentActivity() {
    private var tones: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.gromhork.strive/app").setMethodCallHandler { call, result ->
            when (call.method) {
                // "Exit" while a workout is running: background the task instead of finishing the
                // activity, so the recording (and the process) keeps going.
                "moveTaskToBack" -> result.success(moveTaskToBack(true))
                // Timer signals (lib/services/workout_alerts.dart): a beep and / or a vibration pattern.
                "alert" -> {
                    try {
                        call.argument<String>("tone")?.let { beep(it) }
                        call.argument<List<Int>>("vibrate")?.let { vibrate(it) }
                    } catch (e: Exception) {
                        // A missing vibrator / audio device must never break the workout.
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Short tone on the media stream: audible in headphones and mixed with music (no audio focus).
    private fun beep(kind: String) {
        val g = tones ?: ToneGenerator(AudioManager.STREAM_MUSIC, 90).also { tones = it }
        when (kind) {
            "tick" -> g.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
            "go" -> g.startTone(ToneGenerator.TONE_PROP_BEEP2, 250)
            else -> {
                // End: three beeps, the last one long.
                g.startTone(ToneGenerator.TONE_PROP_BEEP, 150)
                val h = Handler(Looper.getMainLooper())
                h.postDelayed({ tones?.startTone(ToneGenerator.TONE_PROP_BEEP, 150) }, 300)
                h.postDelayed({ tones?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 700) }, 600)
            }
        }
    }

    /// Vibration pattern with alarm usage: unlike haptic feedback it is not silenced by the
    /// "touch vibration" system setting.
    private fun vibrate(pattern: List<Int>) {
        val v: Vibrator =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
        if (!v.hasVibrator()) return
        val effect = VibrationEffect.createWaveform(pattern.map { it.toLong() }.toLongArray(), -1)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            v.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(effect, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
        }
    }

    override fun onDestroy() {
        tones?.release()
        tones = null
        super.onDestroy()
    }
}
