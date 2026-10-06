package com.lagech.delivery

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Native FCM messaging service subclassing Flutter's background messaging service.
 * Intercepts new-order push notifications when backgrounded to show the native WindowManager overlay,
 * preventing duplicate notifications and bypassing Flutter isolate delay.
 */
class LagechMessagingService : FlutterFirebaseMessagingService() {

    companion object {
        private const val TAG = "LagechMessagingService"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"] ?: ""
        Log.i(TAG, "[FCM] MESSAGE RECEIVED (native) type='$type' data=$data")

        when (type) {
            "new_order" -> {
                if (AppForeground.isForeground) {
                    // App is active in foreground — let Flutter in-app dialog handle it
                    Log.d(TAG, "App is in foreground, passing new_order to Flutter")
                    super.onMessageReceived(message)
                } else if (!RiderPrefs.canAcceptMore(applicationContext)) {
                    // The rider already holds the admin's order limit; the server
                    // would refuse the accept, so don't ring for this offer.
                    val orderId = NewOrderOverlay.orderIdOf(data)
                    Log.i(TAG, "Rider is at the order limit — not alerting for $orderId")
                    NewOrderNotifier.cancel(applicationContext, orderId)
                } else {
                    // App is backgrounded or killed — show native WindowManager overlay!
                    Log.i(TAG, "App is backgrounded, attempting native WindowManager overlay...")
                    val shown = NewOrderOverlay.show(applicationContext, data)
                    if (shown) {
                        Log.i(TAG, "overlay shown for ${NewOrderOverlay.orderIdOf(data)} — overlay owns this one, no notification")
                    } else {
                        Log.w(TAG, "Overlay could not be shown (e.g. permission missing). Posting fallback notification.")
                        NewOrderNotifier.show(applicationContext, data)
                    }
                    // Do NOT call super.onMessageReceived(message) here!
                    // This prevents Flutter background isolate from posting a duplicate notification.
                }
            }

            "order_taken", "order_cancelled", "order_deassigned" -> {
                val orderId = NewOrderOverlay.orderIdOf(data)
                Log.i(TAG, "Order withdrawal received ($type) for orderId: $orderId")
                NewOrderOverlay.dismiss(orderId)
                NewOrderNotifier.cancel(applicationContext, orderId)
                // Also let Flutter know so in-app state updates
                super.onMessageReceived(message)
            }

            else -> {
                // Pass all other push types (chat, general updates, etc.) to Flutter
                super.onMessageReceived(message)
            }
        }
    }
}
