package com.ultraelectronica.locker

import io.flutter.embedding.android.FlutterFragmentActivity

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.ultraelectronica.locker/autokill"
    private var isAutoKillEnabled = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setAutoKillEnabled") {
                isAutoKillEnabled = call.arguments as Boolean
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
    
    override fun onPause() {
        super.onPause()
        // Remove from recent apps when user leaves the app, ONLY if enabled
        if (isAutoKillEnabled) {
            finishAndRemoveTask()
        }
    }
}
