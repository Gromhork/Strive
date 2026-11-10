package com.gromhork.strive

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by the Health Connect permission flow.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Exit" while a workout is running: background the task instead of finishing the
        // activity, so the recording (and the process) keeps going.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.gromhork.strive/app").setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> result.success(moveTaskToBack(true))
                else -> result.notImplemented()
            }
        }
    }
}
