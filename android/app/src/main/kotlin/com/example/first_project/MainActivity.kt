package com.example.first_project

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    
    override fun onPause() {
        super.onPause()
        // Remove from recent apps when user leaves the app
        finishAndRemoveTask()
    }
}
