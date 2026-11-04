package com.seddo.customer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

/**
 * Manages native Lock Screen Live Updates for Seddo on Android with Yango-style route visualization.
 * - Single continuous horizontal route line with a moving car separating traveled and remaining distances.
 * - Prominent Lock Screen visibility (VISIBILITY_PUBLIC, CATEGORY_NAVIGATION, Ongoing).
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

    fun isSupported(context: Context): Boolean = true

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

        // Generate the custom Yango-style route bitmap with moving car
        val routeBitmap = generateRouteTrackBitmap(progress)

        // Custom RemoteViews for standard and expanded layouts
        val customView = RemoteViews(context.packageName, R.layout.notification_seddo_live_update).apply {
            setTextViewText(R.id.notification_title, title)
            setTextViewText(R.id.notification_subtitle, contentText)
            setImageViewBitmap(R.id.notification_route_track, routeBitmap)
        }

        val customBigView = RemoteViews(context.packageName, R.layout.notification_seddo_live_update_expanded).apply {
            setTextViewText(R.id.notification_title, title)
            setTextViewText(R.id.notification_subtitle, contentText)
            setImageViewBitmap(R.id.notification_route_track, routeBitmap)
        }

        // Public version shown on Lock Screen even when device is locked without authentication
        val publicNotification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setColor(seddoGreen)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(customView)
            .build()

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setColor(seddoGreen)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(customView)
            .setCustomBigContentView(customBigView)
            .setPublicVersion(publicNotification)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    /**
     * Draws a single seamless horizontal line with:
     * - Origin point (green circle with white core) on the left
     * - Traveled distance line (Seddo Green)
     * - Moving car icon separating traveled and remaining distances
     * - Remaining distance line (subtle neutral track)
     * - Destination point (red circle with white core) on the right
     */
    private fun generateRouteTrackBitmap(progress: Double): Bitmap {
        val width = 1000
        val height = 72
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val paddingX = 40f
        val startX = paddingX
        val endX = width - paddingX
        val trackWidth = endX - startX
        val centerY = height / 2f + 4f
        val trackHeight = 7.5f

        // Progress clamped between 0.06 and 0.94 so the car is always completely on the line
        val clampedProgress = progress.coerceIn(0.06, 0.94).toFloat()
        val carX = startX + trackWidth * clampedProgress

        // 1. Pickup Origin Point (Seddo Green with white core)
        val originPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#16A34A")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(startX, centerY, 8f, originPaint)
        val originCore = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawCircle(startX, centerY, 3.5f, originCore)

        // 2. Traveled Route Line (Vibrant green from origin up to the car)
        val traveledPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#16A34A")
            strokeWidth = trackHeight
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        canvas.drawLine(startX, centerY, carX, centerY, traveledPaint)

        // 3. Remaining Route Line (Subtle translucent track from car to destination)
        val remainingPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#448E8E93")
            strokeWidth = trackHeight
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        canvas.drawLine(carX, centerY, endX, centerY, remainingPaint)

        // 4. Destination Arrival Point (Destination Red with white core)
        val destPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#E11D48")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(endX, centerY, 8f, destPaint)
        val destCore = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawCircle(endX, centerY, 3.5f, destCore)

        // 5. Stylized aerodynamic car moving along the track and facing right
        drawStylizedCar(canvas, carX, centerY - 2f)

        return bitmap
    }

    /**
     * Draws a crisp, aerodynamic vehicle icon positioned horizontally at (x, y) facing forward (right).
     */
    private fun drawStylizedCar(canvas: Canvas, x: Float, y: Float) {
        // Soft drop shadow under the vehicle
        val shadowPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#35000000")
            maskFilter = BlurMaskFilter(4f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawOval(RectF(x - 24f, y + 6f, x + 24f, y + 13f), shadowPaint)

        // Wheels
        val tirePaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#18181B")
            style = Paint.Style.FILL
        }
        val rimPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#E4E4E7")
            style = Paint.Style.FILL
        }
        // Rear wheel (left)
        canvas.drawCircle(x - 15f, y + 7f, 5.2f, tirePaint)
        canvas.drawCircle(x - 15f, y + 7f, 2f, rimPaint)
        // Front wheel (right)
        canvas.drawCircle(x + 15f, y + 7f, 5.2f, tirePaint)
        canvas.drawCircle(x + 15f, y + 7f, 2f, rimPaint)

        // Lower body (chassis)
        val bodyPaint = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        val bodyStroke = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#CBD5E1")
            strokeWidth = 1f
            style = Paint.Style.STROKE
        }
        val bodyRect = RectF(x - 26f, y - 2f, x + 26f, y + 7f)
        canvas.drawRoundRect(bodyRect, 4f, 4f, bodyPaint)
        canvas.drawRoundRect(bodyRect, 4f, 4f, bodyStroke)

        // Seddo Orange Racing Stripe
        val stripePaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#FF6600")
            style = Paint.Style.FILL
        }
        canvas.drawRect(RectF(x - 24f, y + 1.5f, x + 24f, y + 4f), stripePaint)

        // Cabin & Windows (facing right)
        val cabinPath = Path().apply {
            moveTo(x - 15f, y - 2f)
            lineTo(x - 8f, y - 10f)
            lineTo(x + 6f, y - 10f)
            lineTo(x + 15f, y - 2f)
            close()
        }
        val glassPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#0F172A")
            style = Paint.Style.FILL
        }
        canvas.drawPath(cabinPath, glassPaint)

        // Windshield reflection
        val reflectionPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#66FFFFFF")
            strokeWidth = 1.2f
            style = Paint.Style.STROKE
        }
        canvas.drawLine(x + 13f, y - 3f, x + 7f, y - 9f, reflectionPaint)

        // Front Headlight (Warm LED on front right)
        val headlightPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#FBBF24")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(x + 25.5f, y + 1.5f, 2.5f, headlightPaint)

        // Rear Taillight (Red LED on rear left)
        val taillightPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#EF4444")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(x - 25.5f, y + 1.5f, 2f, taillightPaint)
    }

    fun cancelNotification(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
