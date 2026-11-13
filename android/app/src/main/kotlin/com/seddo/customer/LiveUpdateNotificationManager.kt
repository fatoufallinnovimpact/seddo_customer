package com.seddo.customer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.RectF
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

/**
 * Manages native Lock Screen Live Updates for Seddo on Android:
 * - Clean white card with single Seddo brand label (no duplicate SED logo).
 * - Real car color dynamically tinted in top right (no driver profile avatar).
 * - No horizontal line when driver arrives at pickup point.
 * - Solid Seddo Orange (#FB5B00) traveled track + moving ecocar + dashed remaining line (NO circles).
 * - Well-balanced columns to guarantee all text is fully visible without truncation.
 * - Prominent Lock Screen visibility (VISIBILITY_PUBLIC, IMPORTANCE_DEFAULT, Category Navigation).
 */
object LiveUpdateNotificationManager {
    const val CHANNEL_ID = "seddo_live_updates_channel_v7"
    private const val CHANNEL_NAME = "Courses Seddo en direct"
    const val NOTIFICATION_ID = 2026

    private var cachedCarIconTemplate: Bitmap? = null

    private var channelsCleaned = false

    fun createChannelIfNeeded(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (!channelsCleaned) {
                channelsCleaned = true
                listOf(
                    "seddo_live_updates_channel",
                    "seddo_live_updates_channel_v2",
                    "seddo_live_updates_channel_v3",
                    "seddo_live_updates_channel_v4",
                    "seddo_live_updates_channel_v5",
                    "seddo_live_updates_channel_v6"
                ).forEach { oldId ->
                    try {
                        notificationManager.deleteNotificationChannel(oldId)
                    } catch (_: Exception) {}
                }
            }

            val existing = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Affiche l'avancement en temps réel de votre course Seddo sur l'écran verrouillé et le panneau de notification."
                    setSound(null, null)
                    enableLights(false)
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

    fun showOrUpdateNotification(context: Context, data: Map<String, Any?>) {
        try {
            createChannelIfNeeded(context)
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val driverName = data["driverName"] as? String ?: "Chauffeur Seddo"
        val carModel = data["carModel"] as? String ?: "Véhicule Seddo"
        val carColor = data["carColor"] as? String ?: "Gris"
        val licensePlate = data["licensePlate"] as? String ?: ""
        val statusLabel = data["statusLabel"] as? String ?: "Course en cours"
        val phase = data["phase"] as? String ?: ""
        val etaMinutes = (data["etaMinutes"] as? Number)?.toInt() ?: 0
        val rawProgress = (data["progress"] as? Number)?.toDouble() ?: 0.05

        val destinationText = (data["destinationText"] as? String)?.trim() ?: ""

        // Precise phase detection: arrival at pickup takes strict precedence
        val isArrivedAtPickup = phase.equals("driverArrived", ignoreCase = true) ||
            (statusLabel.contains("arrivé", ignoreCase = true) && !statusLabel.contains("destination", ignoreCase = true)) ||
            (statusLabel.contains("prise en charge", ignoreCase = true) && statusLabel.contains("arrivé", ignoreCase = true))

        val isCancelled = phase.equals("cancelled", ignoreCase = true) ||
            statusLabel.contains("annulée", ignoreCase = true) ||
            statusLabel.contains("annulé", ignoreCase = true)

        val isTrip = !isArrivedAtPickup && !isCancelled && (
            phase.equals("inProgress", ignoreCase = true) ||
            statusLabel.contains("destination", ignoreCase = true) ||
            statusLabel.contains("trajet", ignoreCase = true)
        )

        val isFinished = !isArrivedAtPickup && (
            phase.equals("completed", ignoreCase = true) ||
            isCancelled ||
            statusLabel.contains("terminée", ignoreCase = true) ||
            statusLabel.contains("terminé", ignoreCase = true) ||
            (isTrip && rawProgress >= 0.99)
        )

        // Balanced and concise text to match user reference images
        val etaHeadline: String
        val statusSubtitleRaw: String
        val statusSubtitlePlain: String

        when {
            isCancelled -> {
                etaHeadline = "Course annulée"
                statusSubtitleRaw = "La course a été annulée"
                statusSubtitlePlain = "La course a été annulée"
            }
            isFinished -> {
                etaHeadline = "Course terminée"
                statusSubtitleRaw = "Arrivé à destination"
                statusSubtitlePlain = "Arrivé à destination"
            }
            isArrivedAtPickup -> {
                etaHeadline = "Votre chauffeur est arrivé"
                statusSubtitleRaw = "Au point de départ"
                statusSubtitlePlain = "Au point de départ"
            }
            isTrip -> {
                val cleanDest = if (destinationText.isNotBlank()) {
                    val trimmed = destinationText.trim()
                    val commaParts = trimmed.split(",").map { it.trim() }.filter { it.isNotEmpty() }
                    if (commaParts.size > 1 && commaParts[0].length in 3..28) {
                        commaParts[0]
                    } else {
                        trimmed
                    }
                } else {
                    "la destination"
                }
                etaHeadline = "En route vers $cleanDest"
                val etaTimeMillis = System.currentTimeMillis() + (etaMinutes * 60 * 1000L)
                val timeFormat = java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault())
                val etaClock = timeFormat.format(java.util.Date(etaTimeMillis))
                if (etaMinutes > 0) {
                    // Highlights arrival time in Seddo Orange (#FB5B00) matching user reference Image 3
                    statusSubtitleRaw = "Arrivée à <font color='#FB5B00'><b>$etaClock</b></font> · $etaMinutes min"
                    statusSubtitlePlain = "Arrivée à $etaClock · $etaMinutes min"
                } else {
                    statusSubtitleRaw = "Arrivée imminente"
                    statusSubtitlePlain = "Arrivée imminente"
                }
            }
            else -> {
                etaHeadline = if (etaMinutes > 0) "$etaMinutes min avant arrivée" else "Arrivée imminente"
                statusSubtitleRaw = "$driverName arrive bientôt"
                statusSubtitlePlain = "$driverName arrive bientôt"
            }
        }

        val statusSubtitleFormatted: CharSequence = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            android.text.Html.fromHtml(statusSubtitleRaw, android.text.Html.FROM_HTML_MODE_LEGACY)
        } else {
            @Suppress("DEPRECATION")
            android.text.Html.fromHtml(statusSubtitleRaw)
        }

        val plateText = if (licensePlate.isNotBlank()) licensePlate else "DK-482-AB"
        val carText = if (carColor.isNotBlank() && carModel.isNotBlank()) {
            "$carModel $carColor"
        } else if (carModel.isNotBlank()) {
            carModel
        } else {
            "Véhicule Seddo"
        }

        // Dynamically tint vehicle thumbnail to match driver's REAL car color (no profile avatar)
        val tintedCarBmp = getTintedCarBitmap(context, carColor)

        // Generate circular driver avatar with initials matching Image 2
        val driverAvatarBmp = generateDriverAvatarBitmap(driverName)

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

        val seddoOrange = Color.parseColor("#FB5B00")
        val headlineColor = if (isTrip) Color.parseColor("#111827") else Color.parseColor("#FB5B00")

        // Route track line: ONLY when moving/approaching or en route.
        // When driver is arrived at pickup point, NO horizontal line is drawn or shown.
        val showRouteLine = !isArrivedAtPickup && !isFinished
        val routeBitmap = if (showRouteLine) {
            generateRouteTrackBitmap(context, rawProgress, isFinished, carColor)
        } else {
            null
        }

        // Custom RemoteViews for standard and expanded layouts
        val customView = RemoteViews(context.packageName, R.layout.notification_seddo_live_update).apply {
            setImageViewBitmap(R.id.notification_car_thumb, tintedCarBmp)
            setTextViewText(R.id.notification_eta, etaHeadline)
            setTextColor(R.id.notification_eta, headlineColor)
            setTextViewText(R.id.notification_status, statusSubtitleFormatted)
            setTextViewText(R.id.notification_plate, plateText)
            setTextViewText(R.id.notification_driver_name, driverName)
            setTextViewText(R.id.notification_car, carText)
        }

        val customBigView = RemoteViews(context.packageName, R.layout.notification_seddo_live_update_expanded).apply {
            setImageViewBitmap(R.id.notification_car_thumb, tintedCarBmp)
            setTextViewText(R.id.notification_eta, etaHeadline)
            setTextColor(R.id.notification_eta, headlineColor)
            setTextViewText(R.id.notification_status, statusSubtitleFormatted)
            setTextViewText(R.id.notification_plate, plateText)
            setTextViewText(R.id.notification_driver_name, driverName)
            setTextViewText(R.id.notification_car, carText)
            setImageViewBitmap(R.id.notification_driver_avatar, driverAvatarBmp)

            if (showRouteLine && routeBitmap != null) {
                setViewVisibility(R.id.notification_route_track, View.VISIBLE)
                setImageViewBitmap(R.id.notification_route_track, routeBitmap)
            } else {
                setViewVisibility(R.id.notification_route_track, View.GONE)
            }
        }

        // Public version shown on Lock Screen before device unlock (standard BigTextStyle for 100% Keyguard compatibility on Samsung & Android)
        val publicNotification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setColor(seddoOrange)
            .setContentTitle(etaHeadline)
            .setContentText("$statusSubtitlePlain • $plateText")
            .setSubText("Seddo Live")
            .setOngoing(!isFinished)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle(etaHeadline)
                    .bigText("$statusSubtitlePlain\n$driverName • $plateText • $carText")
            )
            .build()

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setColor(seddoOrange)
            .setContentTitle(etaHeadline)
            .setContentText(statusSubtitlePlain)
            .setOngoing(!isFinished)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(customView)
            .setCustomBigContentView(customBigView)
            .setPublicVersion(publicNotification)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
            android.util.Log.d("LiveUpdate", "Notification Seddo affichée avec succès (id=$NOTIFICATION_ID)")
        } catch (t: Throwable) {
            android.util.Log.e("LiveUpdate", "Erreur lors de l'affichage de la notification Live: ${t.message}", t)
        }
    }


    /**
     * Generates a circular avatar bitmap with driver initials matching Image 2
     * (Dark charcoal circle #263238 with bold white initials, e.g. "MD" or "M").
     */
    private fun generateDriverAvatarBitmap(driverName: String): Bitmap {
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#263238")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)

        val parts = driverName.trim().split(" ").filter { it.isNotBlank() }
        val initials = when {
            parts.size >= 2 -> "${parts[0].first().uppercaseChar()}${parts[1].first().uppercaseChar()}"
            parts.size == 1 -> parts[0].take(2).uppercase()
            else -> "S"
        }

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 38f
            typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val yPos = (canvas.height / 2f) - ((textPaint.descent() + textPaint.ascent()) / 2f)
        canvas.drawText(initials, canvas.width / 2f, yPos, textPaint)
        return bitmap
    }

    /**
     * Tints the vehicle thumbnail icon to match the driver's actual car color,
     * mirroring the exact iOS Live Activity implementation (SF Symbol "car.side.fill" tinted with carTint).
     * Uses a pure white side-view car vector template tinted cleanly via PorterDuff.Mode.SRC_IN.
     */
    private fun getTintedCarBitmap(context: Context, carColorStr: String?): Bitmap {
        var template = cachedCarIconTemplate
        if (template == null) {
            template = BitmapFactory.decodeResource(context.resources, R.drawable.ic_seddo_car_side_icon)
            if (template == null) {
                template = BitmapFactory.decodeResource(context.resources, R.drawable.ic_seddo_car_thumb)
            }
            cachedCarIconTemplate = template
        }
        if (template == null) {
            return Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        }

        val targetColor = parseCarColor(carColorStr)
        val tinted = Bitmap.createBitmap(template.width, template.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(tinted)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            colorFilter = PorterDuffColorFilter(targetColor, PorterDuff.Mode.SRC_IN)
        }
        canvas.drawBitmap(template, 0f, 0f, paint)
        return tinted
    }

    /**
     * Maps textual or hex vehicle color representation into an Android Color Int.
     * Matches the exact color palette used in iOS Live Activity carTint(from:).
     */
    private fun parseCarColor(colorStr: String?): Int {
        if (colorStr.isNullOrBlank()) return Color.parseColor("#9CA3AF")
        val clean = colorStr.trim().lowercase()

        // Hex check
        if (clean.startsWith("#") && (clean.length == 7 || clean.length == 9)) {
            try {
                return Color.parseColor(clean)
            } catch (_: Exception) {}
        }

        return when {
            clean.contains("noir") || clean.contains("black") -> Color.parseColor("#262626") // Color(white: 0.15)
            clean.contains("blanc") || clean.contains("white") -> Color.parseColor("#D9D9D9") // Color(white: 0.85)
            clean.contains("rouge") || clean.contains("red") || clean.contains("bordeaux") -> Color.parseColor("#DC2626") // rgb(220, 38, 38)
            clean.contains("bleu") || clean.contains("blue") -> Color.parseColor("#2563EB") // rgb(37, 99, 235)
            clean.contains("jaune") || clean.contains("yellow") -> Color.parseColor("#F59E0B") // rgb(245, 158, 11)
            clean.contains("gris") || clean.contains("grey") || clean.contains("gray") || clean.contains("argent") || clean.contains("silver") ->
                Color.parseColor("#9CA3AF") // rgb(156, 163, 175)
            clean.contains("vert") || clean.contains("green") -> Color.parseColor("#16A34A") // rgb(22, 163, 74)
            clean.contains("orange") -> Color.parseColor("#EA580C") // rgb(234, 88, 12)
            clean.contains("marron") || clean.contains("brown") -> Color.parseColor("#8C461E") // rgb(140, 70, 30)
            else -> Color.parseColor("#9CA3AF")
        }
    }

    /**
     * Draws a single seamless horizontal route line:
     * - Solid continuous horizontal track (NO dashed line, trait plein)
     * - Solid Seddo Orange (#FB5B00) line up to the moving car
     * - Moving Top-Down car sitting on the track colored with REAL vehicle color (1:1 replica of iOS TopDownCarView)
     * - Destination flag on the extreme right
     */
    private fun generateRouteTrackBitmap(context: Context, progress: Double, isFinished: Boolean, carColorStr: String): Bitmap {
        val width = 1000
        val height = 78
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val paddingX = 28f
        val startX = paddingX
        val endX = width - paddingX - 16f
        val trackWidth = endX - startX
        val centerY = height / 2f
        val trackHeight = 3.5f * 2.8f // 9.8f matching iOS lineWidth 3.5

        // Progress goes strictly from left (startX) to right (endX)
        val normalizedProgress = if (isFinished) 1.0f else progress.coerceIn(0.06, 0.94).toFloat()
        val carX = if (isFinished) endX else (startX + trackWidth * normalizedProgress)

        // 1. Full solid horizontal route line across the entire track (NO dashed line, trait plein)
        val remainingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#CBD5E1")
            strokeWidth = trackHeight
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        canvas.drawLine(startX, centerY, endX, centerY, remainingPaint)

        // 2. Traveled Route Line: Continuous solid Seddo Orange (#FB5B00) line on the left
        val traveledPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#FB5B00")
            strokeWidth = trackHeight
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        val traveledEndX = if (isFinished) endX else carX
        canvas.drawLine(startX, centerY, traveledEndX, centerY, traveledPaint)

        // 3. Arrival Point Icon: White destination flag sitting directly at the end of the horizontal line
        drawDestinationFlag(context, canvas, endX, centerY)

        // 4. Draw the moving car sitting on the track using the Apple car icon (matching iOS car.side.fill)
        drawTrackCarIcon(context, canvas, carX, centerY, carColorStr)

        return bitmap
    }

    /**
     * Draws the white destination flag icon (assets/icons/flag-svgrepo-com.svg)
     * positioned directly at the end of the route track.
     */
    private fun drawDestinationFlag(context: Context, canvas: Canvas, x: Float, y: Float) {
        try {
            val drawable = androidx.core.content.ContextCompat.getDrawable(context, R.drawable.ic_destination_flag_white)
            if (drawable != null) {
                val size = 20
                val poleOffsetX = 4f
                drawable.setBounds(
                    (x - size / 2f + poleOffsetX).toInt(),
                    (y - size / 2f - 1).toInt(),
                    (x + size / 2f + poleOffsetX).toInt(),
                    (y + size / 2f - 1).toInt()
                )
                drawable.draw(canvas)
                return
            }
        } catch (_: Exception) {}

        // Canvas fallback drawing compact white flagpole and flag with slate stroke
        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#64748B")
            strokeWidth = 1.5f
            style = Paint.Style.STROKE
        }
        val flagPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        val banner = Path().apply {
            moveTo(x + 0.5f, y - 10f)
            lineTo(x + 12f, y - 5.5f)
            lineTo(x + 0.5f, y - 1f)
            close()
        }
        canvas.drawPath(banner, flagPaint)
        canvas.drawPath(banner, strokePaint)
        canvas.drawRect(RectF(x - 1.5f, y - 10f, x + 0.5f, y + 9f), flagPaint)
        canvas.drawRect(RectF(x - 1.5f, y - 10f, x + 0.5f, y + 9f), strokePaint)
        canvas.drawCircle(x - 0.5f, y - 10.5f, 1.8f, flagPaint)
        canvas.drawCircle(x - 0.5f, y - 10.5f, 1.8f, strokePaint)
    }

    /**
     * Draws the side-view vehicle icon moving along the route track,
     * using the exact same Apple vector car icon (SF Symbol "car.side.fill" tinted with real vehicle color)
     * as used on iOS SeddoRouteTrackView.
     */
    private fun drawTrackCarIcon(context: Context, canvas: Canvas, x: Float, y: Float, carColorStr: String) {
        val carBmp = getTintedCarBitmap(context, carColorStr)
        if (carBmp.width <= 1) return

        val carWidth = 66f
        val carHeight = carWidth * (carBmp.height.toFloat() / carBmp.width.toFloat()) // ~30.2f
        val carLeft = x - (carWidth / 2f)
        val carTop = y - (carHeight / 2f)

        // Drop shadow matching iOS .shadow(color: Color.black.opacity(0.45), radius: 2, x: 0, y: 1)
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
            colorFilter = PorterDuffColorFilter(Color.argb(100, 0, 0, 0), PorterDuff.Mode.SRC_IN)
        }
        val shadowRect = RectF(carLeft, carTop + 2f, carLeft + carWidth, carTop + carHeight + 2f)
        canvas.drawBitmap(carBmp, null, shadowRect, shadowPaint)

        // Tinted car icon on the track
        val carPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        val destRect = RectF(carLeft, carTop, carLeft + carWidth, carTop + carHeight)
        canvas.drawBitmap(carBmp, null, destRect, carPaint)
    }

    fun cancelNotification(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
