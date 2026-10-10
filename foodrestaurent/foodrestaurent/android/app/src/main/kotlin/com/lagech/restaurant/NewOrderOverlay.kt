package com.lagech.restaurant

import android.app.KeyguardManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/**
 * The new-order card drawn over whatever the restaurant has open — the same overlay
 * the delivery app shows riders.
 *
 * Accept and Reject are not handled here. They are sent to [NewOrderActionReceiver],
 * the receiver behind the notification's own buttons, so a decision taken on the
 * overlay reaches Dart and the server by exactly the same path.
 *
 * Only used while the phone is unlocked: an overlay window cannot draw over the lock
 * screen, and there the notification's full-screen intent is what wakes the
 * restaurant. [canShow] makes that call before anything is committed.
 */
object NewOrderOverlay {

    private const val TAG = "NewOrderOverlay"

    private val mainHandler = Handler(Looper.getMainLooper())

    // Touched on the main thread only.
    private var windowManager: WindowManager? = null
    private var activeView: View? = null
    private var countDownTimer: CountDownTimer? = null
    private var showingIds: Set<String> = emptySet()

    /** Permission granted and the screen is not behind the keyguard. */
    fun canShow(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
            Log.i(TAG, "overlay permission not granted")
            return false
        }
        val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (keyguard?.isKeyguardLocked == true) {
            Log.i(TAG, "device locked — leaving this one to the full-screen notification")
            return false
        }
        return true
    }

    /**
     * Draws the card and starts the ring. [onFailed] runs if the window could not be
     * added after all, so the caller can fall back to the notification instead of
     * the order going unannounced.
     */
    fun show(
        context: Context,
        data: Map<String, String>,
        canonicalId: String,
        allIds: Collection<String>,
        ringMillis: Long,
        onFailed: () -> Unit,
    ) {
        val appContext = context.applicationContext
        val ids = (allIds + canonicalId).filter { it.isNotBlank() }.toSet()

        mainHandler.post {
            try {
                val current = activeView
                if (current != null && showingIds.any { it in ids }) {
                    Log.d(TAG, "order $canonicalId already on screen — rebinding")
                    bind(appContext, current, data, canonicalId)
                    return@post
                }
                if (current != null) removeLocked()

                val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    type,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                    PixelFormat.TRANSLUCENT,
                ).apply {
                    gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    y = 20
                }

                val view = LayoutInflater.from(appContext).inflate(R.layout.overlay_new_order, null)
                bind(appContext, view, data, canonicalId)
                wm.addView(view, params)

                windowManager = wm
                activeView = view
                showingIds = ids

                val timeout = timeoutMillis(data, ringMillis)
                NewOrderRingtone.start(appContext, ids, timeout)
                startCountdown(view, timeout)
                Log.i(TAG, "overlay shown for $canonicalId")
            } catch (t: Throwable) {
                Log.e(TAG, "could not show overlay for $canonicalId", t)
                removeLocked()
                onFailed()
            }
        }
    }

    /** Takes the card down if it is showing [orderId] (any alias), or any order when null. */
    fun dismiss(orderId: String?) {
        mainHandler.post {
            if (activeView == null) return@post
            if (orderId == null || orderId in showingIds) {
                NewOrderRingtone.stop(null)
                removeLocked()
            }
        }
    }

    private fun removeLocked() {
        countDownTimer?.cancel()
        countDownTimer = null
        try {
            activeView?.let { windowManager?.removeViewImmediate(it) }
        } catch (t: Throwable) {
            Log.w(TAG, "removing overlay failed", t)
        } finally {
            activeView = null
            windowManager = null
            showingIds = emptySet()
        }
    }

    private fun bind(context: Context, root: View, data: Map<String, String>, orderId: String) {
        root.findViewById<TextView>(R.id.tv_order_display_id).text =
            (data["orderDisplayId"] ?: data["orderNumber"])?.takeIf { it.isNotBlank() }
                ?: "#${orderId.takeLast(6).uppercase(Locale.ROOT)}"

        fun amount(key: String): Double? =
            data[key]?.replace(Regex("[^0-9.]"), "")?.toDoubleOrNull()

        // The restaurant's earning after commission, labelled "You earn"; the
        // customer's total only from an older server that does not send it.
        val earning = amount("restaurantEarning")
        val total = earning ?: amount("total") ?: amount("amount")
        root.findViewById<TextView>(R.id.tv_amount_label).visibility =
            if (earning != null) View.VISIBLE else View.GONE
        root.findViewById<TextView>(R.id.tv_amount).text =
            if (total != null) String.format(Locale.US, "₹ %.2f", total) else "New order"

        val itemCountView = root.findViewById<TextView>(R.id.tv_item_count)
        val itemCount = data["itemCount"]?.toIntOrNull()
        if (itemCount != null && itemCount > 0) {
            itemCountView.text = if (itemCount == 1) "1 item" else "$itemCount items"
            itemCountView.visibility = View.VISIBLE
        } else {
            itemCountView.visibility = View.GONE
        }

        val paymentView = root.findViewById<TextView>(R.id.tv_payment)
        val method = data["paymentMethod"]?.lowercase(Locale.ROOT)?.trim().orEmpty()
        paymentView.text = when {
            method.isEmpty() -> ""
            method == "cash" || method == "cod" -> "COD"
            else -> "Paid"
        }
        paymentView.visibility = if (method.isEmpty()) View.GONE else View.VISIBLE

        // The socket path stringifies whole objects ("{street: ...}"); only plain text is shown.
        fun text(key: String): String? =
            data[key]?.trim()?.takeIf { it.isNotEmpty() && !it.startsWith("{") && !it.startsWith("[") }

        val items = text("itemsList") ?: text("itemsSummary")
        root.findViewById<View>(R.id.layout_items).visibility =
            if (items != null) View.VISIBLE else View.GONE
        root.findViewById<TextView>(R.id.tv_items).text = items.orEmpty()

        root.findViewById<TextView>(R.id.tv_customer_name).text =
            data["customerName"]?.takeIf { it.isNotBlank() } ?: "Customer"
        val address = text("address") ?: text("customerAddress") ?: text("body") ?: ""
        root.findViewById<TextView>(R.id.tv_customer_address).apply {
            text = address
            visibility = if (address.isEmpty()) View.GONE else View.VISIBLE
        }

        root.findViewById<Button>(R.id.btn_reject).setOnClickListener {
            Log.i(TAG, "reject pressed on overlay for $orderId")
            sendDecision(context, NewOrderNotifier.ACTION_REJECT, orderId)
        }
        root.findViewById<Button>(R.id.btn_accept).setOnClickListener {
            Log.i(TAG, "accept pressed on overlay for $orderId")
            sendDecision(context, NewOrderNotifier.ACTION_ACCEPT, orderId)
        }
    }

    private fun sendDecision(context: Context, action: String, orderId: String) {
        // Accept brings the app forward. This has to happen while the overlay
        // window is still on screen: that visible window is what lets Android allow
        // a background launch, and it is gone once the overlay is removed below.
        if (action == NewOrderNotifier.ACTION_ACCEPT) openApp(context, orderId)

        // Off the screen and silent before anything else, as on the notification.
        NewOrderRingtone.stop(null)
        removeLocked()
        context.sendBroadcast(
            Intent(context, NewOrderActionReceiver::class.java).apply {
                this.action = action
                putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
            },
        )
    }

    private fun openApp(context: Context, orderId: String) {
        try {
            val launch = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                    )
                    putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
                } ?: return
            PendingIntent.getActivity(
                context,
                NewOrderNotifier.notificationId(orderId),
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ).send()
        } catch (t: Throwable) {
            Log.w(TAG, "could not open the app from the overlay", t)
        }
    }

    private fun startCountdown(root: View, millis: Long) {
        val timer = root.findViewById<TextView>(R.id.tv_countdown_timer)
        countDownTimer?.cancel()
        countDownTimer = object : CountDownTimer(millis, 1000) {
            override fun onTick(remaining: Long) {
                timer.text = "${(remaining / 1000).coerceAtLeast(1)}s"
            }

            override fun onFinish() {
                // The backend expires the order on its own; the card just stops asking.
                NewOrderRingtone.stop(null)
                removeLocked()
            }
        }.start()
    }

    /** Time left on the server's acceptance deadline, else the notifier's ring window. */
    private fun timeoutMillis(data: Map<String, String>, fallback: Long): Long {
        val deadline = data["acceptanceDeadlineAt"]?.takeIf { it.isNotBlank() } ?: return fallback
        for (pattern in listOf("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'")) {
            try {
                val format = SimpleDateFormat(pattern, Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                val at = format.parse(deadline) ?: continue
                val remaining = at.time - System.currentTimeMillis()
                // A push delayed past the deadline (Doze) must not open at zero.
                return if (remaining > 5_000L) remaining else fallback
            } catch (_: Exception) {
            }
        }
        return fallback
    }
}
