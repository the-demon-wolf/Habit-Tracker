package com.example.habit_tracker

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var openTodayPending = false
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (intent?.getBooleanExtra("open_today", false) == true) {
            openTodayPending = true
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "habit_tracker/nav")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "checkOpenToday") {
                result.success(openTodayPending)
                openTodayPending = false
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("open_today", false)) {
            channel?.invokeMethod("openToday", null)
        }
    }
}
