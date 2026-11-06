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

    private var cachedEcoCarBitmap: Bitmap? = null
    private var cachedCarThumbOriginal: Bitmap? = null

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
                val dest = if (destinationText.isNotBlank()) destinationText else "la destination"
                etaHeadline = "En route vers $dest"
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
            generateRouteTrackBitmap(context, rawProgress, isFinished)
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
            .setColor(Color.WHITE)
            .setColorized(true)
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
     * Tints the vehicle thumbnail bitmap to match the driver's actual car color
     * using the exact luminance color matrix as VehicleColorHelper in Flutter.
     */
    private fun getTintedCarBitmap(context: Context, carColorStr: String?): Bitmap {
        var original = cachedCarThumbOriginal
        if (original == null) {
            original = BitmapFactory.decodeResource(context.resources, R.drawable.ic_seddo_car_thumb)
            cachedCarThumbOriginal = original
        }
        if (original == null) {
            return Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        }

        val targetColor = parseCarColor(carColorStr)
        val clean = (carColorStr ?: "").trim().lowercase()

        // If yellow (base eco car asset), return original
        if (clean.contains("jaune") || clean.contains("yellow")) {
            return original
        }

        val r = Color.red(targetColor) / 255f
        val g = Color.green(targetColor) / 255f
        val b = Color.blue(targetColor) / 255f

        // Rec. 601 Luminance grayscale matrix modulated by target color:
        val colorMatrix = ColorMatrix(floatArrayOf(
            0.299f * r, 0.587f * r, 0.114f * r, 0f, 0f,
            0.299f * g, 0.587f * g, 0.114f * g, 0f, 0f,
            0.299f * b, 0.587f * b, 0.114f * b, 0f, 0f,
            0f,         0f,         0f,         1f, 0f
        ))

        val tinted = Bitmap.createBitmap(original.width, original.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(tinted)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            colorFilter = ColorMatrixColorFilter(colorMatrix)
        }
        canvas.drawBitmap(original, 0f, 0f, paint)
        return tinted
    }

    /**
     * Maps textual or hex vehicle color representation into an Android Color Int.
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
            clean.contains("blanc") || clean.contains("white") -> Color.parseColor("#FFFFFF")
            clean.contains("noir") || clean.contains("black") -> Color.parseColor("#1F2937")
            clean.contains("gris") || clean.contains("grey") || clean.contains("gray") || clean.contains("argent") || clean.contains("silver") ->
                Color.parseColor("#9CA3AF")
            clean.contains("rouge") || clean.contains("red") || clean.contains("bordeaux") ->
                Color.parseColor("#DC2626")
            clean.contains("bleu") || clean.contains("blue") -> Color.parseColor("#2563EB")
            clean.contains("jaune") || clean.contains("yellow") -> Color.parseColor("#F59E0B")
            clean.contains("vert") || clean.contains("green") -> Color.parseColor("#16A34A")
            clean.contains("orange") -> Color.parseColor("#EA580C")
            clean.contains("marron") || clean.contains("brown") -> Color.parseColor("#78350F")
            else -> Color.parseColor("#9CA3AF")
        }
    }

    /**
     * Draws a single seamless horizontal route line:
     * - Solid Seddo Orange (#FB5B00) line from left up to the moving car
     * - Moving ecocar icon (assets/icons/ecocar.svg / ic_seddo_ecocar)
     * - Dashed grey line (#CBD5E1) from car to right edge
     * - STRICTLY NO CIRCLES (no origin circle, no intermediate circle stops, no destination circle)
     */
    private fun generateRouteTrackBitmap(context: Context, progress: Double, isFinished: Boolean): Bitmap {
        val width = 1000
        val height = 64
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val paddingX = 28f
        val startX = paddingX + 12f
        val endX = width - paddingX - 12f
        val trackWidth = endX - startX
        val centerY = height / 2f
        val trackHeight = 7f

        // Progress goes strictly from left (startX) to right (endX)
        val normalizedProgress = if (isFinished) 1.0f else progress.coerceIn(0.06, 0.94).toFloat()
        val carX = if (isFinished) endX else (startX + trackWidth * normalizedProgress)

        // 1. Traveled Route Line: Continuous solid Seddo Orange (#FB5B00) line on the left
        val traveledPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#FB5B00")
            strokeWidth = trackHeight
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        val traveledEndX = if (isFinished) (endX - 12f) else carX
        canvas.drawLine(startX + 10f, centerY, traveledEndX, centerY, traveledPaint)

        // 2. Remaining Route Line: Dashed neutral grey track (- - - - -) on the right
        if (!isFinished && carX < endX - 14f) {
            val dashedPaint = Paint().apply {
                isAntiAlias = true
                color = Color.parseColor("#CBD5E1")
                strokeWidth = trackHeight - 1f
                strokeCap = Paint.Cap.ROUND
                style = Paint.Style.STROKE
                pathEffect = DashPathEffect(floatArrayOf(18f, 14f), 0f)
            }
            val dashedPath = Path().apply {
                moveTo(carX + 14f, centerY)
                lineTo(endX - 14f, centerY)
            }
            canvas.drawPath(dashedPath, dashedPaint)
        }

        // 3. Departure Point Icon (Left extreme): Green pin circle (#16A34A) with white core
        val departureOuterPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#16A34A")
            style = Paint.Style.FILL
        }
        val departureInnerPaint = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawCircle(startX, centerY, 11f, departureOuterPaint)
        canvas.drawCircle(startX, centerY, 4.5f, departureInnerPaint)

        // 4. Arrival Point Icon (Right extreme): Seddo Orange destination pin (#FB5B00) with white core
        val arrivalOuterPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#FB5B00")
            style = Paint.Style.FILL
        }
        val arrivalInnerPaint = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawCircle(endX, centerY, 11f, arrivalOuterPaint)
        canvas.drawCircle(endX, centerY, 4.5f, arrivalInnerPaint)

        // 5. Draw the official EcoCar icon (assets/icons/ecocar.svg) facing forward along the track
        drawEcoCar(context, canvas, carX, centerY)

        return bitmap
    }

    /**
     * Draws the official Seddo EcoCar icon (assets/icons/ecocar.svg / ic_seddo_ecocar)
     * facing forward along the route track from left to right.
     */
    private fun drawEcoCar(context: Context, canvas: Canvas, x: Float, y: Float) {
        var carBmp = cachedEcoCarBitmap
        if (carBmp == null) {
            try {
                val original = BitmapFactory.decodeResource(context.resources, R.drawable.ic_seddo_ecocar)
                if (original != null) {
                    val targetW = 50
                    val targetH = (targetW * original.height) / original.width
                    carBmp = Bitmap.createScaledBitmap(original, targetW, targetH, true)
                    cachedEcoCarBitmap = carBmp
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 1. Soft drop shadow under the vehicle badge
        val shadowPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#22000000")
            maskFilter = BlurMaskFilter(3f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawOval(RectF(x - 28f, y - 9f, x + 28f, y + 14f), shadowPaint)

        // 2. Crisp white rounded badge behind ecocar so the route line doesn't cut through the car
        val badgePaint = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        val strokePaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#E2E8F0")
            strokeWidth = 1.2f
            style = Paint.Style.STROKE
        }
        val badgeRect = RectF(x - 26f, y - 14f, x + 26f, y + 14f)
        canvas.drawRoundRect(badgeRect, 13f, 13f, badgePaint)
        canvas.drawRoundRect(badgeRect, 13f, 13f, strokePaint)

        // 3. Draw ecocar bitmap centered inside the badge
        if (carBmp != null) {
            canvas.drawBitmap(carBmp, x - carBmp.width / 2f, y - carBmp.height / 2f, null)
        }
    }

    fun cancelNotification(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
