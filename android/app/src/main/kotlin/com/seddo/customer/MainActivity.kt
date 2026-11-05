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
                    val rawMap = call.arguments as? Map<*, *>
                    if (rawMap != null) {
                        val args = rawMap.entries.associate { (it.key?.toString() ?: "") to it.value }
                        LiveUpdateNotificationManager.showOrUpdateNotification(this, args)
                        result.success(LiveUpdateNotificationManager.NOTIFICATION_ID.toString())
                    } else {
                        result.error("INVALID_ARGS", "Arguments attendus", null)
                    }
                }
                "updateLiveUpdate" -> {
                    val rawMap = call.arguments as? Map<*, *>
                    if (rawMap != null) {
                        val args = rawMap.entries.associate { (it.key?.toString() ?: "") to it.value }
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

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleTestNotification(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        handleTestNotification(intent)
    }

    private fun handleTestNotification(intent: android.content.Intent?) {
        if (intent?.getBooleanExtra("test_live_notification", false) == true) {
            val phase = intent.getStringExtra("phase") ?: "driverApproaching"
            val dest = intent.getStringExtra("destinationText") ?: "Plateau"
            val etaMinutes = intent.getIntExtra("etaMinutes", if (phase == "inProgress") 18 else 3)
            val progress = intent.getDoubleExtra("progress", if (phase == "inProgress") 0.35 else 0.45)
            val testData = mapOf<String, Any>(
                "driverName" to (intent.getStringExtra("driverName") ?: "Moussa"),
                "carModel" to (intent.getStringExtra("carModel") ?: "Toyota Corolla"),
                "carColor" to (intent.getStringExtra("carColor") ?: "blanche"),
                "licensePlate" to (intent.getStringExtra("licensePlate") ?: "DK-482-AB"),
                "statusLabel" to (intent.getStringExtra("statusLabel") ?: if (phase == "inProgress") "En route vers destination" else "Chauffeur en approche"),
                "phase" to phase,
                "destinationText" to dest,
                "etaMinutes" to etaMinutes,
                "progress" to progress
            )
            LiveUpdateNotificationManager.showOrUpdateNotification(this, testData)
        }
    }
}
