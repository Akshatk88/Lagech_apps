package com.lagech.delivery

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles Reject action from fallback notification without opening the app.
 * Queues the rejection into SharedPreferences so Flutter reports it on next launch.
 */
class RejectOrderReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "RejectOrderReceiver"
        const val PREFS_NAME = "lagech_delivery_prefs"
        const val KEY_PENDING_REJECTIONS = "pending_rejections"

        fun recordRejection(context: Context, orderId: String) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val current = prefs.getStringSet(KEY_PENDING_REJECTIONS, emptySet())?.toMutableSet() ?: mutableSetOf()
                current.add(orderId)
                prefs.edit().putStringSet(KEY_PENDING_REJECTIONS, current).apply()
                Log.d(TAG, "Recorded pending rejection for orderId: $orderId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to record rejection for $orderId: ${e.message}", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val orderId = intent.getStringExtra("orderId") ?: return
        Log.d(TAG, "onReceive reject for orderId: $orderId")

        // Dismiss any overlay and cancel notification
        NewOrderOverlay.dismiss(orderId)
        NewOrderNotifier.cancel(context, orderId)

        // Record rejection in SharedPreferences
        recordRejection(context, orderId)
    }
}
