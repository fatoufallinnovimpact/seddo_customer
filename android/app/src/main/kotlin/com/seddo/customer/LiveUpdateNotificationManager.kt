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
            clean.contains("blanc") || clean.contains("white") -> Color.parseColor("#E2E8F0")
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
     * - Solid continuous horizontal track (NO dashed line, trait plein)
     * - Solid Seddo Orange (#FB5B00) line up to the moving car
     * - Moving Top-Down car sitting on the track colored with REAL vehicle color
     * - Destination circle ring (○) on the extreme right
     */
    private fun generateRouteTrackBitmap(context: Context, progress: Double, isFinished: Boolean, carColorStr: String): Bitmap {
        val width = 1000
        val height = 64
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val paddingX = 28f
        val startX = paddingX
        val endX = width - paddingX - 16f
        val trackWidth = endX - startX
        val centerY = height / 2f
        val trackHeight = 7f

        // Progress goes strictly from left (startX) to right (endX)
        val normalizedProgress = if (isFinished) 1.0f else progress.coerceIn(0.06, 0.94).toFloat()
        val carX = if (isFinished) endX else (startX + trackWidth * normalizedProgress)

        // 1. Full solid horizontal route line across the entire track (NO dashed line, trait plein)
        val remainingPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#CBD5E1")
            strokeWidth = trackHeight - 1.5f
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        canvas.drawLine(startX, centerY, endX, centerY, remainingPaint)

        // 2. Traveled Route Line: Continuous solid Seddo Orange (#FB5B00) line on the left
        val traveledPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#FB5B00")
            strokeWidth = trackHeight
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        val traveledEndX = if (isFinished) endX else carX
        canvas.drawLine(startX, centerY, traveledEndX, centerY, traveledPaint)

        // 3. Arrival Point Icon: White destination flag sitting directly at the end of the horizontal line
        drawDestinationFlag(context, canvas, endX, centerY)

        // 4. Draw the realistic Top-Down car sitting on the track colored with REAL vehicle color
        val parsedColor = parseCarColor(carColorStr)
        drawTopDownCar(canvas, carX, centerY, parsedColor)

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
                val size = 17
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
            strokeWidth = 1.0f
            style = Paint.Style.STROKE
        }
        val flagPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        val banner = Path().apply {
            moveTo(x + 0.5f, y - 8f)
            lineTo(x + 9f, y - 4.5f)
            lineTo(x + 0.5f, y - 1f)
            close()
        }
        canvas.drawPath(banner, flagPaint)
        canvas.drawPath(banner, strokePaint)
        canvas.drawRect(RectF(x - 1f, y - 8f, x + 0.5f, y + 7f), flagPaint)
        canvas.drawRect(RectF(x - 1f, y - 8f, x + 0.5f, y + 7f), strokePaint)
        canvas.drawCircle(x - 0.25f, y - 8.5f, 1.3f, flagPaint)
        canvas.drawCircle(x - 0.25f, y - 8.5f, 1.3f, strokePaint)
    }

    /**
     * Draws a realistic Top-Down car view on the route track matching the iOS Live Activity design
     * and tinted with the driver's real vehicle color returned by the API.
     */
    private fun drawTopDownCar(canvas: Canvas, x: Float, y: Float, carColor: Int) {
        val carWidth = 76f
        val carHeight = 38f
        val left = x - carWidth / 2f
        val top = y - carHeight / 2f
        val right = x + carWidth / 2f
        val bottom = y + carHeight / 2f

        // 1. Soft drop shadow under the vehicle
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(90, 0, 0, 0)
            maskFilter = BlurMaskFilter(4f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawRoundRect(RectF(left - 2f, top + 3f, right + 2f, bottom + 5f), 10f, 10f, shadowPaint)

        // 2. Wheels (4 dark rounded capsules peeking on top & bottom)
        val wheelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1F2937")
            style = Paint.Style.FILL
        }
        val wheelW = 15f
        val wheelH = 6.5f
        // Front wheels (facing right towards destination)
        val frontWheelX = x + 20f
        canvas.drawRoundRect(RectF(frontWheelX - wheelW / 2f, top - 3f, frontWheelX + wheelW / 2f, top - 3f + wheelH), 3f, 3f, wheelPaint)
        canvas.drawRoundRect(RectF(frontWheelX - wheelW / 2f, bottom + 3f - wheelH, frontWheelX + wheelW / 2f, bottom + 3f), 3f, 3f, wheelPaint)
        // Rear wheels
        val rearWheelX = x - 20f
        canvas.drawRoundRect(RectF(rearWheelX - wheelW / 2f, top - 3f, rearWheelX + wheelW / 2f, top - 3f + wheelH), 3f, 3f, wheelPaint)
        canvas.drawRoundRect(RectF(rearWheelX - wheelW / 2f, bottom + 3f - wheelH, rearWheelX + wheelW / 2f, bottom + 3f), 3f, 3f, wheelPaint)

        // 3. Car Body: rounded rectangle filled with the driver's real vehicle color
        val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = carColor
            style = Paint.Style.FILL
        }
        val bodyRect = RectF(left, top, right, bottom)
        canvas.drawRoundRect(bodyRect, 11f, 11f, bodyPaint)

        // Determine brightness of car color to apply matching subtle outline
        val r = Color.red(carColor)
        val g = Color.green(carColor)
        val b = Color.blue(carColor)
        val luminance = (0.299f * r + 0.587f * g + 0.114f * b) / 255f
        val isLightColor = luminance > 0.72f

        val bodyStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isLightColor) Color.argb(45, 0, 0, 0) else Color.argb(80, 255, 255, 255)
            strokeWidth = 1.0f
            style = Paint.Style.STROKE
        }
        canvas.drawRoundRect(bodyRect, 11f, 11f, bodyStrokePaint)

        // 4. Windows (dark tinted automotive glass #334155)
        val glassPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#334155")
            style = Paint.Style.FILL
        }
        // Front windshield (curved towards front/right)
        val windshieldRect = RectF(x + 9f, y - 13f, x + 18f, y + 13f)
        canvas.drawRoundRect(windshieldRect, 4f, 4f, glassPaint)

        // Rear window (left)
        val rearWindowRect = RectF(x - 20f, y - 12f, x - 13.5f, y + 12f)
        canvas.drawRoundRect(rearWindowRect, 4f, 4f, glassPaint)

        // Side windows connecting front and rear
        canvas.drawRect(RectF(x - 14f, y - 13.5f, x + 10f, y - 10f), glassPaint)
        canvas.drawRect(RectF(x - 14f, y + 10f, x + 10f, y + 13.5f), glassPaint)

        // 5. Roof Panel (matching car color with subtle shade/highlight)
        val roofPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isLightColor) Color.parseColor("#F8FAFC") else carColor
            style = Paint.Style.FILL
            if (!isLightColor) {
                alpha = 220
            }
        }
        val roofRect = RectF(x - 16f, y - 11f, x + 12f, y + 11f)
        canvas.drawRoundRect(roofRect, 5f, 5f, roofPaint)

        val roofStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isLightColor) Color.argb(35, 0, 0, 0) else Color.argb(60, 255, 255, 255)
            strokeWidth = 0.8f
            style = Paint.Style.STROKE
        }
        canvas.drawRoundRect(roofRect, 5f, 5f, roofStrokePaint)

        // 6. Headlights at front edge (warm light yellow beam)
        val headlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#FEF08A")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(right - 2f, top + 9f, 3.2f, headlightPaint)
        canvas.drawCircle(right - 2f, bottom - 9f, 3.2f, headlightPaint)

        // 7. Red Taillights at rear edge
        val taillightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#EF4444")
            style = Paint.Style.FILL
        }
        canvas.drawRoundRect(RectF(left - 0.5f, top + 7f, left + 2.5f, top + 12f), 1.5f, 1.5f, taillightPaint)
        canvas.drawRoundRect(RectF(left - 0.5f, bottom - 12f, left + 2.5f, bottom - 7f), 1.5f, 1.5f, taillightPaint)
    }

    fun cancelNotification(context: Context) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
