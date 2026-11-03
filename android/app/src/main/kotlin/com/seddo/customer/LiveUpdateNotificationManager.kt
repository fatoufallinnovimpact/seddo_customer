package com.seddo.customer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Manages native Lock Screen Live Updates for Seddo on Android.
 * - Under Android 16 (API 36 Baklava): Uses the official Notification.ProgressStyle
 *   with segmented progress tracks and zero RemoteViews.
 * - Under Android < 16: Uses graceful fallback with standard NotificationCompat ongoing progress.
 */
object LiveUpdateNotificationManager {
    const val CHANNEL_ID = "seddo_live_updates_channel"
    private const val CHANNEL_NAME = "Courses Seddo en direct"
    const val NOTIFICATION_ID = 2026

    fun createChannelIfNeeded(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Affiche l'avancement de votre course en temps réel sur l'écran verrouillé."
                    enableLights(true)
                    lightColor = Color.parseColor("#16A34A") // Seddo primary green
                    enableVibration(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                notificationManager.createNotificationChannel(channel)
            }
        }
    }

    fun isSupported(context: Context): Boolean {
        return true
    }

    fun areActivitiesEnabled(context: Context): Boolean {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            return notificationManager.areNotificationsEnabled()
        }
        return true
    }

    fun showOrUpdateNotification(context: Context, data: Map<String, Any>) {
        createChannelIfNeeded(context)
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val driverName = data["driverName"] as? String ?: "Chauffeur Seddo"
        val carModel = data["carModel"] as? String ?: "Véhicule Seddo"
        val carColor = data["carColor"] as? String ?: "Gris"
        val licensePlate = data["licensePlate"] as? String ?: ""
        val statusLabel = data["statusLabel"] as? String ?: "Course en cours"
        val etaMinutes = (data["etaMinutes"] as? Number)?.toInt() ?: 0
        val progress = (data["progress"] as? Number)?.toDouble() ?: 0.2
        val progressPercent = (progress * 100).toInt().coerceIn(0, 100)

        val etaText = if (etaMinutes > 0) "$etaMinutes min" else "Arrivé"
        val title = "$statusLabel • $etaText"
        val contentText = "$driverName • $carModel ($carColor) • $licensePlate"

        // Intent opening the app when tapped
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val seddoGreen = Color.parseColor("#16A34A")

        // 1. Android 16 (API 36) True Live Update using Notification.ProgressStyle (No RemoteViews)
        if (Build.VERSION.SDK_INT >= 36) {
            try {
                val progressStyleClass = Class.forName("android.app.Notification\$ProgressStyle")
                val progressStyleInstance = progressStyleClass.getConstructor().newInstance()

                // progressStyle.setProgress(progressPercent)
                progressStyleClass.getMethod("setProgress", Int::class.javaPrimitiveType)
                    .invoke(progressStyleInstance, progressPercent)

                val builder = Notification.Builder(context, CHANNEL_ID)
                    .setContentTitle(title)
                    .setContentText(contentText)
                    .setSmallIcon(context.applicationInfo.icon)
                    .setColor(seddoGreen)
                    .setOngoing(true)
                    .setOnlyAlertOnce(true)
                    .setVisibility(Notification.VISIBILITY_PUBLIC)
                    .setContentIntent(pendingIntent)

                // builder.setStyle(progressStyle)
                val setStyleMethod = builder.javaClass.getMethod("setStyle", Class.forName("android.app.Notification\$Style"))
                setStyleMethod.invoke(builder, progressStyleInstance)

                notificationManager.notify(NOTIFICATION_ID, builder.build())
                return
            } catch (e: Throwable) {
                // In case of reflection discrepancy, fall back smoothly to NotificationCompat
            }
        }

        // 2. Android < 16 Fallback: Ongoing Notification with progress bar
        val compatBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSmallIcon(context.applicationInfo.icon)
            .setColor(seddoGreen)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setProgress(100, progressPercent, false)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle(title)
                    .bigText("$contentText\nProgression du trajet : $progressPercent%")
            )

        notificationManager.notify(NOTIFICATION_ID, compatBuilder.build())
    }

    fun cancelNotification(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
