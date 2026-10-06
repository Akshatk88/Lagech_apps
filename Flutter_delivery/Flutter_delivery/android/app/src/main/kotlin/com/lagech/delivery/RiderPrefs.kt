package com.lagech.delivery

import android.content.Context
import android.util.Log
import org.json.JSONObject

/**
 * Rider settings the Dart side persists with shared_preferences, read natively
 * so the background new-order overlay / notification obey them even when the
 * Flutter engine is not running.
 *
 * shared_preferences (legacy API) stores everything in the
 * "FlutterSharedPreferences" file with keys prefixed "flutter.":
 *   - flutter.rider_business_settings  JSON string (BusinessSettingsCache)
 *   - flutter.rider_can_accept_more    boolean (RiderCapacityCache)
 * Any missing or unreadable value falls back to the app's old behaviour.
 */
object RiderPrefs {

    private const val TAG = "RiderPrefs"
    private const val FILE = "FlutterSharedPreferences"
    private const val KEY_BUSINESS_SETTINGS = "flutter.rider_business_settings"
    private const val KEY_CAN_ACCEPT_MORE = "flutter.rider_can_accept_more"

    /** Admin's "show earning to rider" switch; true when unknown. */
    fun showEarning(context: Context): Boolean {
        return try {
            val raw = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
                .getString(KEY_BUSINESS_SETTINGS, null)
            if (raw.isNullOrBlank()) true else JSONObject(raw).optBoolean("showEarning", true)
        } catch (e: Exception) {
            Log.w(TAG, "showEarning unreadable, showing earnings: ${e.message}")
            true
        }
    }

    /**
     * Whether the rider has room for another delivery (`canAcceptMore` from
     * /orders/current, last seen by the app); true when unknown.
     */
    fun canAcceptMore(context: Context): Boolean {
        return try {
            val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            if (!prefs.contains(KEY_CAN_ACCEPT_MORE)) true else prefs.getBoolean(KEY_CAN_ACCEPT_MORE, true)
        } catch (e: Exception) {
            Log.w(TAG, "canAcceptMore unreadable, allowing offers: ${e.message}")
            true
        }
    }
}
