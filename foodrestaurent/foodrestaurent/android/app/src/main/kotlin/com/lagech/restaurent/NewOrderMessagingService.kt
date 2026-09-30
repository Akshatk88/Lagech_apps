package com.lagech.restaurent

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Raises the new-order alert from Kotlin, the moment the push lands.
 *
 * ## Why this exists
 *
 * The alert used to be drawn by `flutter_local_notifications` from the Dart
 * background handler, which only runs once a Flutter engine has been started. When
 * the app is killed, or the phone has been sitting idle, that happens late or not at
 * all — so the alert arrived silently, or long after the order did. This runs before
 * any engine is involved.
 *
 * ## Why it extends FlutterFirebaseMessagingService
 *
 * Android gives the MESSAGING_EVENT intent filter to exactly ONE service. A plain
 * `FirebaseMessagingService` declared here would win that election and silently
 * displace the `firebase_messaging` plugin's own service — Dart would stop receiving
 * pushes entirely, taking every other notification in the app with it. The symptom is
 * brutal to diagnose, because this alert keeps working perfectly while everything
 * else goes quiet.
 *
 * Extending the plugin's service and calling `super` keeps both paths alive.
 */
class NewOrderMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val notification = message.notification
        val rawType = (data["type"] ?: data["eventType"] ?: data["event"])?.lowercase()?.trim()
        val orderId = orderIdOf(data)
        val notifTitle = (notification?.title ?: data["title"] ?: "").lowercase()

        Log.i(TAG, "FCM received: rawType=$rawType id=$orderId notifTitle=$notifTitle")

        val isNewOrder = rawType in NEW_ORDER_TYPES ||
            (rawType?.contains("order") == true &&
                !rawType.contains("cancel") &&
                !rawType.contains("reject") &&
                !rawType.contains("deliver") &&
                !rawType.contains("taken")) ||
            notifTitle.contains("new order") ||
            notifTitle.contains("order created") ||
            notifTitle.contains("order placed") ||
            notifTitle.contains("order received") ||
            notifTitle.contains("naya order") ||
            (orderId != null && rawType == null)

        val isCloseOrder = rawType in CLOSE_TYPES ||
            rawType?.contains("cancel") == true ||
            rawType?.contains("reject") == true

        if (isNewOrder || isCloseOrder) {
            try {
                if (isNewOrder) {
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
                } else if (isCloseOrder) {
                    NewOrderNotifier.dismiss(applicationContext, orderId)
                }
            } catch (t: Throwable) {
                Log.e(TAG, "failed to post new-order alert", t)
                if (isNewOrder) {
                    try {
                        NewOrderNotifier.showFallback(applicationContext, data)
                    } catch (_: Throwable) {
                    }
                }
            }
        }

        super.onMessageReceived(message)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }

    companion object {
        private const val TAG = "NewOrderFcm"

        private val NEW_ORDER_TYPES = setOf(
            "new_order",
            "order_created",
            "order_placed",
            "neworder",
            "order",
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
        )

        fun orderIdOf(data: Map<String, String>): String? {
            val direct = listOf("orderMongoId", "orderId", "_id", "id", "order_id", "orderDisplayId", "mongoId")
                .asSequence()
                .mapNotNull { data[it] }
                .firstOrNull { it.isNotBlank() }

            if (direct != null) return direct

            for (key in listOf("order", "data")) {
                val jsonStr = data[key]
                if (!jsonStr.isNullOrBlank() && jsonStr.startsWith("{")) {
                    try {
                        val json = org.json.JSONObject(jsonStr)
                        for (idKey in listOf("orderMongoId", "orderId", "_id", "id", "orderDisplayId", "order_id")) {
                            if (json.has(idKey)) {
                                val v = json.optString(idKey)
                                if (v.isNotBlank()) return v
                            }
                        }
                    } catch (_: Exception) {}
                }
            }

            return null
        }
    }
}
