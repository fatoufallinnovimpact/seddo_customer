package com.seddo.customer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sn.innov.seddo/live_updates"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> {
                    result.success(LiveUpdateNotificationManager.isSupported(this))
                }
                "areActivitiesEnabled" -> {
                    result.success(LiveUpdateNotificationManager.areActivitiesEnabled(this))
                }
                "startLiveUpdate" -> {
                    val args = call.arguments as? Map<String, Any>
                    if (args != null) {
                        LiveUpdateNotificationManager.showOrUpdateNotification(this, args)
                        result.success(LiveUpdateNotificationManager.NOTIFICATION_ID.toString())
                    } else {
                        result.error("INVALID_ARGS", "Arguments attendus", null)
                    }
                }
                "updateLiveUpdate" -> {
                    val args = call.arguments as? Map<String, Any>
                    if (args != null) {
                        LiveUpdateNotificationManager.showOrUpdateNotification(this, args)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Arguments attendus", null)
                    }
                }
                "endLiveUpdate" -> {
                    LiveUpdateNotificationManager.cancelNotification(this)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
