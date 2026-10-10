package com.lagech.restaurant

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import java.util.concurrent.ConcurrentHashMap

/**
 * Handles incoming FCM pushes for restaurant orders.
 *
 * When app is in BACKGROUND or KILLED:
 *  - Native Kotlin shows the high-priority heads-up alert with Accept / Reject buttons.
 *  - Native Kotlin plays the looping ringtone (USAGE_ALARM).
 *  - Exception: needsAcceptance == "false" (already confirmed by the delivery partner)
 *    gets a plain notification instead — no Accept/Reject, no ring, no full-screen.
 *  - super.onMessageReceived is NOT called to prevent Flutter's background isolate from
 *    spawning and posting a duplicate notification with duplicate sound.
 *
 * When app is in FOREGROUND:
 *  - FCM push is forwarded to Flutter via super.onMessageReceived so the in-app
 *    order dialog and live orders controller handle the alert cleanly.
 */
class NewOrderMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val notification = message.notification
        val rawType = (data["type"] ?: data["eventType"] ?: data["event"])?.lowercase()?.trim()
        val allIds = allOrderIdsOf(data)
        val orderId = allIds.firstOrNull()
        val notifTitle = (notification?.title ?: data["title"] ?: "").lowercase()

        Log.i(TAG, "FCM received: rawType=$rawType ids=$allIds notifTitle=$notifTitle needsAcceptance=${data["needsAcceptance"]} foreground=${AppForeground.isForeground}")

        val isNewOrder = rawType in NEW_ORDER_TYPES
        val statusVal = (data["orderStatus"] ?: data["status"] ?: "").lowercase()
        val isCloseOrder = rawType in CLOSE_TYPES || statusVal.contains("cancel") || statusVal.contains("reject")

        if (isNewOrder) {
            try {
                if (isDuplicateAlert(allIds)) {
                    Log.i(TAG, "Deduplicated new-order push for order: $orderId (aliases=$allIds)")
                    return
                }

                if (!AppForeground.isForeground) {
                    // App is backgrounded or killed: native Kotlin handles the notification + alarm sound
                    Log.i(TAG, "App is in background/killed, showing native NewOrderNotifier alert")
                    val mergedData = HashMap<String, String>(data)
                    if (notification?.title?.isNotBlank() == true && !mergedData.containsKey("title")) {
                        mergedData["title"] = notification.title!!
                    }
                    if (notification?.body?.isNotBlank() == true && !mergedData.containsKey("body")) {
                        mergedData["body"] = notification.body!!
                    }
                    if (orderId != null && !mergedData.containsKey("orderId")) {
                        mergedData["orderId"] = orderId
                    }
                    NewOrderNotifier.show(applicationContext, mergedData)

                    // Do NOT call super.onMessageReceived(message) here!
                    // This prevents Flutter background isolate from posting a duplicate notification
                    // and playing duplicate sound!
                    return
                } else {
                    // App is in foreground: let Flutter in-app dialog and order controller handle it
                    Log.i(TAG, "App is in foreground, passing new_order push to Flutter engine")
                    super.onMessageReceived(message)
                    return
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to handle new-order push", t)
                if (!AppForeground.isForeground) {
                    try {
                        NewOrderNotifier.showFallback(applicationContext, data)
                    } catch (_: Throwable) {}
                }
                return
            }
        }

        if (isCloseOrder) {
            try {
                NewOrderNotifier.dismiss(applicationContext, orderId)
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to dismiss order on close event", t)
            }
            super.onMessageReceived(message)
            return
        }

        // Pass all other push types (chat, general updates, etc.) to Flutter
        super.onMessageReceived(message)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }

    companion object {
        private const val TAG = "NewOrderFcm"
        private val recentAlerts = ConcurrentHashMap<String, Long>()
        private const val DEDUPE_WINDOW_MS = 30_000L

        fun isDuplicateAlert(ids: Collection<String>): Boolean {
            if (ids.isEmpty()) return false
            val now = System.currentTimeMillis()
            val isDupe = ids.any { id ->
                val last = recentAlerts[id]
                last != null && (now - last) < DEDUPE_WINDOW_MS
            }
            if (isDupe) return true

            recordAlert(ids)
            return false
        }

        fun recordAlert(ids: Collection<String>) {
            if (ids.isEmpty()) return
            val now = System.currentTimeMillis()
            for (id in ids) {
                if (id.isNotBlank()) {
                    recentAlerts[id] = now
                }
            }
            if (recentAlerts.size > 150) {
                val cutoff = now - (5 * 60_000L)
                recentAlerts.entries.removeIf { it.value < cutoff }
            }
        }

        private val NEW_ORDER_TYPES = setOf(
            "new_order",
            "order_created",
            "order_placed",
            "neworder",
            "order_received",
            "new_order_available",
        )

        /** Order taken elsewhere, cancelled, or withdrawn by the backend. */
        private val CLOSE_TYPES = setOf(
            "order_taken",
            "order_cancelled",
            "cancel_order",
            "new_order_closed",
            "order_expired",
            "order_rejected",
            "cancelled_by_restaurant",
            "cancelled_by_user",
            "cancelled_by_admin",
        )

        fun allOrderIdsOf(data: Map<String, String>): List<String> {
            val list = mutableListOf<String>()
            listOf("orderMongoId", "orderId", "_id", "id", "order_id", "orderDisplayId", "mongoId")
                .forEach { key ->
                    data[key]?.takeIf { it.isNotBlank() }?.let { if (!list.contains(it)) list.add(it) }
                }

            for (key in listOf("order", "data")) {
                val jsonStr = data[key]
                if (!jsonStr.isNullOrBlank() && jsonStr.startsWith("{")) {
                    try {
                        val json = org.json.JSONObject(jsonStr)
                        for (idKey in listOf("orderMongoId", "orderId", "_id", "id", "orderDisplayId", "order_id")) {
                            if (json.has(idKey)) {
                                val v = json.optString(idKey)
                                if (v.isNotBlank() && !list.contains(v)) list.add(v)
                            }
                        }
                    } catch (_: Exception) {}
                }
            }
            return list
        }

        fun orderIdOf(data: Map<String, String>): String? {
            return allOrderIdsOf(data).firstOrNull()
        }
    }
}
