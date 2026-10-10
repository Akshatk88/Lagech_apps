package com.lagech.restaurant

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles Accept and Reject pressed on the new-order notification.
 *
 * Silencing and clearing the alert happens HERE, synchronously, before anything that
 * can be slow or fail. The restaurant pressed a button; the ringing has to stop that
 * instant, whether or not the network call that follows succeeds.
 *
 * The status update itself is carried out by Dart, which already owns the auth token
 * and the API client. [PendingOrderAction] hands the decision over immediately when
 * the app's engine is alive, and parks it otherwise.
 */
class NewOrderActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val orderId = intent.getStringExtra(NewOrderNotifier.EXTRA_ORDER_ID)
        if (orderId.isNullOrBlank()) return

        val accepted = when (action) {
            NewOrderNotifier.ACTION_ACCEPT -> true
            NewOrderNotifier.ACTION_REJECT -> false
            else -> return
        }
        Log.i(TAG, "action=${if (accepted) "accept" else "reject"} order=$orderId")

        // Stop the noise first, always.
        NewOrderRingtone.stop(null)
        NewOrderOverlay.dismiss(orderId)
        try {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NewOrderNotifier.notificationId(orderId))
        } catch (_: Throwable) {
        }

        PendingOrderAction.set(orderId = orderId, accepted = accepted)

        // Only Accept opens the app.
        //
        // Accepting means the kitchen has work to do and needs the order on screen.
        // Rejecting does not — pulling the restaurant into the app to tell them
        // nothing happened is worse than staying out of the way. The rejection still
        // reaches the server: PendingOrderAction hands it straight to Dart when the
        // engine is alive, and otherwise it is sent the next time the app is opened,
        // with the backend's own unaccepted-order expiry as the final backstop.
        if (accepted) {
            try {
                val launch = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
                    }
                if (launch != null) context.startActivity(launch)
            } catch (t: Throwable) {
                // Could not bring the app forward. The action is still queued, so Dart
                // picks it up whenever the app is next opened.
                Log.w(TAG, "could not launch app after accept", t)
            }
        }
    }

    private companion object {
        const val TAG = "NewOrderAction"
    }
}

/**
 * The restaurant's decision, parked until Dart can act on it.
 *
 * Process-static rather than persisted: the decision is only meaningful inside the
 * acceptance window, and an order that outlives the process has expired anyway.
 * Restoring one from disk after a cold start would confirm an order that no longer
 * exists.
 */
object PendingOrderAction {

    @Volatile
    private var pending: Map<String, Any?>? = null

    /**
     * Set by [MainActivity] while its Flutter engine exists, so a decision can be
     * handed to Dart the instant it is made.
     *
     * This is what lets Reject reach the server without opening the app.
     */
    @Volatile
    var listener: ((Map<String, Any?>) -> Unit)? = null

    @Synchronized
    fun set(orderId: String, accepted: Boolean) {
        val action = mapOf<String, Any?>("orderId" to orderId, "accepted" to accepted)
        pending = action

        // Delivered live when Dart is listening, and cleared so the poll on next
        // resume cannot act on the same decision twice.
        listener?.let { deliver ->
            pending = null
            deliver(action)
        }
    }

    /** Read-and-clear: acting on one decision twice would double-submit. */
    @Synchronized
    fun consume(): Map<String, Any?>? {
        val value = pending
        pending = null
        return value
    }

    @Synchronized
    fun hasPending(): Boolean = pending != null
}
