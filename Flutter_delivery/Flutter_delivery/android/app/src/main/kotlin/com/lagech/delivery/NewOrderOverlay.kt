package com.lagech.delivery

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.PowerManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/**
 * Native WindowManager overlay for incoming orders.
 * Shows over any screen or lock screen without launching the full app or clipping notification layout.
 */
object NewOrderOverlay {

    private const val TAG = "NewOrderOverlay"
    private const val DEFAULT_TIMEOUT_SECONDS = 45L

    @Volatile
    var showingOrderId: String? = null
        private set

    @Volatile
    private var windowManager: WindowManager? = null

    @Volatile
    private var activeOverlayView: View? = null

    @Volatile
    private var countDownTimer: CountDownTimer? = null

    @Volatile
    private var mediaPlayer: MediaPlayer? = null

    @Volatile
    private var vibrator: Vibrator? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun isShowing(): Boolean = activeOverlayView != null

    /**
     * Shows or updates the native overlay for a new order.
     * Returns true if overlay was shown or rebound, false if permission missing or orderId empty.
     */
    fun show(context: Context, data: Map<String, String>): Boolean {
        val appContext = context.applicationContext
        val orderId = orderIdOf(data)
        if (orderId.isNullOrBlank()) {
            Log.w(TAG, "Cannot show overlay: orderId missing in data: $data")
            return false
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(appContext)) {
            Log.w(TAG, "Cannot show overlay: Settings.canDrawOverlays is false")
            return false
        }

        mainHandler.post {
            try {
                if (showingOrderId == orderId && activeOverlayView != null) {
                    Log.d(TAG, "Order $orderId already showing on overlay — rebinding in place")
                    bindViewData(appContext, activeOverlayView!!, data, orderId)
                    return@post
                }

                // If another order is showing, dismiss it first
                if (activeOverlayView != null) {
                    dismissLocked(appContext)
                }

                val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                windowManager = wm

                val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }

                @Suppress("DEPRECATION")
                val flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    layoutType,
                    flags,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    y = 20
                }

                val inflater = LayoutInflater.from(appContext)
                val view = inflater.inflate(R.layout.overlay_new_order, null)

                bindViewData(appContext, view, data, orderId)

                wm.addView(view, params)
                activeOverlayView = view
                showingOrderId = orderId

                startRingtoneAndVibration(appContext)
                startCountdown(appContext, view, data, orderId)

                Log.i(TAG, "NewOrderOverlay shown successfully for order $orderId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to show NewOrderOverlay: ${e.message}", e)
                dismissLocked(appContext)
            }
        }

        return true
    }

    /**
     * Dismisses the overlay if it is currently showing the given orderId (or any order if null).
     */
    fun dismiss(orderId: String? = null) {
        mainHandler.post {
            if (orderId == null || showingOrderId == orderId) {
                dismissLocked(null)
            }
        }
    }

    private fun dismissLocked(context: Context?) {
        try {
            stopRingtoneAndVibration()
            countDownTimer?.cancel()
            countDownTimer = null

            activeOverlayView?.let { view ->
                windowManager?.removeViewImmediate(view)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing overlay view: ${e.message}")
        } finally {
            activeOverlayView = null
            showingOrderId = null
            windowManager = null
        }
    }

    private fun bindViewData(context: Context, root: View, data: Map<String, String>, orderId: String) {
        val tvOrderDisplayId = root.findViewById<TextView>(R.id.tv_order_display_id)
        val tvEarnings = root.findViewById<TextView>(R.id.tv_earnings)
        val tvDistance = root.findViewById<TextView>(R.id.tv_distance)
        val tvDuration = root.findViewById<TextView>(R.id.tv_duration)
        val tvRestaurantName = root.findViewById<TextView>(R.id.tv_restaurant_name)
        val tvPickupAddress = root.findViewById<TextView>(R.id.tv_pickup_address)
        val tvCustomerName = root.findViewById<TextView>(R.id.tv_customer_name)
        val tvDropAddress = root.findViewById<TextView>(R.id.tv_drop_address)
        val layoutMap = root.findViewById<FrameLayout>(R.id.layout_map_container)
        val ivMap = root.findViewById<ImageView>(R.id.iv_static_map)
        val btnDecline = root.findViewById<Button>(R.id.btn_decline)
        val btnAccept = root.findViewById<Button>(R.id.btn_accept)

        // Order display ID
        val displayId = data["orderDisplayId"]
            ?: data["orderNumber"]
            ?: data["displayId"]
            ?: "#${orderId.takeLast(4).uppercase(Locale.ROOT)}"
        tvOrderDisplayId.text = displayId

        // Earnings
        val earning = data["riderEarning"]
            ?: data["earnings"]
            ?: data["price"]
            ?: data["total"]
            ?: "0"
        val cleanEarning = earning.replace(Regex("[^0-9.]"), "")
        val formattedEarning = cleanEarning.toDoubleOrNull()?.let { String.format(Locale.US, "₹ %.2f", it) }
            ?: "₹ $earning"
        // Customer tip is already inside the earning; call it out separately.
        val tip = data["riderTip"]?.toDoubleOrNull() ?: 0.0
        tvEarnings.text = if (tip > 0) {
            val suffix = String.format(Locale.US, "  incl. ₹%.0f tip", tip)
            android.text.SpannableString(formattedEarning + suffix).apply {
                setSpan(
                    android.text.style.RelativeSizeSpan(0.5f),
                    formattedEarning.length,
                    length,
                    android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
        } else {
            formattedEarning
        }
        // Admin's "show earning to rider" switch (Business Settings), as the
        // Flutter screens already obey it.
        tvEarnings.visibility = if (RiderPrefs.showEarning(context)) View.VISIBLE else View.GONE

        // Distance & Duration
        val distance = data["tripDistanceKm"]
            ?: data["distance"]
            ?: data["distanceKm"]
        tvDistance.text = if (!distance.isNullOrBlank()) {
            val dVal = distance.toDoubleOrNull()
            if (dVal != null) String.format(Locale.US, "%.1f km", dVal) else "$distance km"
        } else {
            "2.5 km"
        }

        val duration = data["tripDurationMins"]
            ?: data["duration"]
            ?: data["durationMins"]
        tvDuration.text = if (!duration.isNullOrBlank()) "$duration mins" else "15-25 mins"

        // Restaurant (Pickup)
        val restaurant = data["restaurantName"]?.takeIf { it.isNotBlank() } ?: "Restaurant Partner"
        tvRestaurantName.text = restaurant
        val pickupAddr = data["restaurantAddress"]
            ?: data["pickupAddress"]
            ?: data["restaurantLocation"]
            ?: "Pickup Location"
        tvPickupAddress.text = pickupAddr

        // Customer (Drop)
        val customer = data["customerName"]?.takeIf { it.isNotBlank() } ?: "Customer"
        tvCustomerName.text = customer
        val dropAddr = data["customerAddress"]
            ?: data["dropAddress"]
            ?: data["deliveryAddress"]
            ?: "Customer Drop Location"
        tvDropAddress.text = dropAddr

        // Decline Button
        btnDecline.setOnClickListener {
            Log.d(TAG, "Rider clicked DECLINE for order $orderId")
            dismissLocked(context)
            RejectOrderReceiver.recordRejection(context, orderId)
        }

        // Accept Button
        btnAccept.setOnClickListener {
            Log.d(TAG, "Rider clicked ACCEPT for order $orderId")
            // The activity is launched while the overlay window is still on screen:
            // that visible window is what lets Android allow a background launch.
            // The overlay is removed afterwards.

            // Wake screen if device is locked or display is off
            try {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                if (powerManager?.isInteractive == false) {
                    @Suppress("DEPRECATION")
                    val wakeLock = powerManager.newWakeLock(
                        PowerManager.FULL_WAKE_LOCK or
                                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                                PowerManager.ON_AFTER_RELEASE,
                        "lagech:overlay_accept"
                    )
                    wakeLock.acquire(10_000L)
                }
            } catch (e: Exception) {
                Log.w(TAG, "WakeLock acquire failed: ${e.message}")
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                putExtra("orderId", orderId)
                putExtra("autoAccept", true)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
            }

            if (launchIntent != null) {
                try {
                    val notifId = (orderId.hashCode() and 0x7fffffff)
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        notifId,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    pendingIntent.send()
                    Log.i(TAG, "Successfully triggered PendingIntent to launch app for order $orderId")
                } catch (e: Exception) {
                    Log.w(TAG, "PendingIntent send failed, falling back to startActivity: ${e.message}")
                    try {
                        context.startActivity(launchIntent)
                    } catch (e2: Exception) {
                        Log.e(TAG, "startActivity failed: ${e2.message}", e2)
                    }
                }
            } else {
                Log.e(TAG, "Launch intent for package ${context.packageName} was null")
            }

            dismissLocked(context)
        }

        // Google Maps Static Preview
        loadStaticMap(context, data, layoutMap, ivMap)
    }

    private fun loadStaticMap(
        context: Context,
        data: Map<String, String>,
        layoutMap: FrameLayout,
        ivMap: ImageView
    ) {
        val pickupLat = data["pickupLat"]?.toDoubleOrNull()
        val pickupLng = data["pickupLng"]?.toDoubleOrNull()
        val dropLat = data["dropLat"]?.toDoubleOrNull()
        val dropLng = data["dropLng"]?.toDoubleOrNull()

        if (pickupLat == null || pickupLng == null || dropLat == null || dropLng == null) {
            layoutMap.visibility = View.GONE
            return
        }

        val apiKey = try {
            val appInfo = context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA
            )
            appInfo.metaData?.getString("com.google.android.geo.API_KEY")
        } catch (e: Exception) {
            null
        }

        if (apiKey.isNullOrBlank()) {
            layoutMap.visibility = View.GONE
            return
        }

        val mapUrl = "https://maps.googleapis.com/maps/api/staticmap?" +
                "size=600x200&scale=2&maptype=roadmap&" +
                "markers=color:0x16A34A|label:P|$pickupLat,$pickupLng&" +
                "markers=color:0xEF4444|label:D|$dropLat,$dropLng&" +
                "key=$apiKey"

        Thread {
            var connection: HttpURLConnection? = null
            var inputStream: InputStream? = null
            try {
                val url = URL(mapUrl)
                connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 4000
                connection.readTimeout = 4000
                connection.doInput = true
                connection.connect()

                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    inputStream = connection.inputStream
                    val bitmap: Bitmap? = BitmapFactory.decodeStream(inputStream)
                    if (bitmap != null) {
                        mainHandler.post {
                            if (activeOverlayView != null) {
                                ivMap.setImageBitmap(bitmap)
                                layoutMap.visibility = View.VISIBLE
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "Static map preview not available: ${e.message}")
            } finally {
                try { inputStream?.close() } catch (_: Exception) {}
                try { connection?.disconnect() } catch (_: Exception) {}
            }
        }.start()
    }

    private fun startCountdown(
        context: Context,
        root: View,
        data: Map<String, String>,
        orderId: String
    ) {
        val tvTimer = root.findViewById<TextView>(R.id.tv_countdown_timer)
        val durationMillis = resolveTimeoutMillis(data)

        countDownTimer?.cancel()
        countDownTimer = object : CountDownTimer(durationMillis, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val seconds = (millisUntilFinished / 1000).coerceAtLeast(1)
                tvTimer.text = "${seconds}s"
            }

            override fun onFinish() {
                Log.d(TAG, "Overlay timer expired for order $orderId")
                tvTimer.text = "0s"
                dismissLocked(context)
            }
        }.start()
    }

    private fun resolveTimeoutMillis(data: Map<String, String>): Long {
        val fallback = DEFAULT_TIMEOUT_SECONDS * 1000L

        // 1. Try acceptanceDeadlineAt ISO timestamp
        val deadlineAt = data["acceptanceDeadlineAt"]
        if (!deadlineAt.isNullOrBlank()) {
            try {
                val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                val deadlineDate = format.parse(deadlineAt)
                if (deadlineDate != null) {
                    val remaining = deadlineDate.time - System.currentTimeMillis()
                    // If deadline is already in the past (e.g. push delayed by Doze),
                    // NEVER open at zero — give full fallback window.
                    if (remaining > 5000L) {
                        return remaining
                    }
                }
            } catch (_: Exception) {}
        }

        // 2. Try acceptTimeoutSeconds
        val timeoutSeconds = data["acceptTimeoutSeconds"]?.toLongOrNull()
        if (timeoutSeconds != null && timeoutSeconds > 5L) {
            return timeoutSeconds * 1000L
        }

        return fallback
    }

    private fun startRingtoneAndVibration(context: Context) {
        stopRingtoneAndVibration()

        // Ringtone
        try {
            val soundUri = Uri.parse("android.resource://${context.packageName}/raw/neworder")
            val mp = MediaPlayer().apply {
                setDataSource(context, soundUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
            mediaPlayer = mp
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start overlay ringtone: ${e.message}")
        }

        // Vibration
        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            vibrator = vib
            if (vib != null && vib.hasVibrator()) {
                val pattern = longArrayOf(0, 500, 300, 500, 300, 500)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vib.vibrate(VibrationEffect.createWaveform(pattern, -1))
                } else {
                    @Suppress("DEPRECATION")
                    vib.vibrate(pattern, -1)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start vibration: ${e.message}")
        }
    }

    private fun stopRingtoneAndVibration() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
        } catch (_: Exception) {} finally {
            mediaPlayer = null
        }

        try {
            vibrator?.cancel()
        } catch (_: Exception) {} finally {
            vibrator = null
        }
    }

    fun orderIdOf(data: Map<String, String>): String? {
        val raw = data["orderMongoId"] ?: data["orderId"] ?: data["id"]
        return raw?.trim()?.takeIf { it.isNotEmpty() }
    }
}
