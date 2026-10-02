package com.lagech.delivery

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Locale

/**
 * Fallback notification alert with high importance, fullScreenIntent, and Accept/Reject buttons
 * when the native WindowManager overlay cannot be shown (e.g. SYSTEM_ALERT_WINDOW not granted).
 */
object NewOrderNotifier {

    private const val TAG = "NewOrderNotifier"

    const val CHANNEL_ID_V4 = "incoming_orders_channel_v4"
    const val CHANNEL_ID_V3 = "incoming_orders_channel_v3"
    private const val CHANNEL_NAME = "Incoming Delivery Orders"

    fun notificationId(orderId: String?): Int =
        (orderId ?: "new_delivery_order").hashCode() and 0x7fffffff

    private fun getSmallIcon(context: Context): Int {
        val icId = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
        if (icId != 0) return icId
        val resId = context.resources.getIdentifier("launcher_icon", "mipmap", context.packageName)
        if (resId != 0) return resId
        return if (context.applicationInfo.icon != 0) context.applicationInfo.icon else android.R.drawable.ic_dialog_info
    }

    fun show(context: Context, data: Map<String, String>) {
        val orderId = NewOrderOverlay.orderIdOf(data) ?: return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        createChannels(context, manager)
        wakeScreen(context)

        val soundUri = Uri.parse("android.resource://${context.packageName}/raw/neworder")

        val restaurant = data["restaurantName"]?.takeIf { it.isNotBlank() } ?: "New Order"
        val earning = data["riderEarning"] ?: data["earnings"] ?: data["price"] ?: data["total"] ?: ""
        val distance = data["tripDistanceKm"] ?: data["distance"] ?: ""
        val title = "New Order: ₹$earning ($restaurant)"
        val body = "Pickup at $restaurant • Distance: $distance km. Tap to view and accept."

        val smallIcon = getSmallIcon(context)
        val notifId = notificationId(orderId)

        // Accept Intent -> Launches MainActivity with autoAccept=true
        val acceptIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            putExtra("orderId", orderId)
            putExtra("autoAccept", true)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
        }
        val acceptPendingIntent = PendingIntent.getActivity(
            context,
            notifId * 2 + 1,
            acceptIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Reject Intent -> Broadcasts to RejectOrderReceiver
        val rejectIntent = Intent(context, RejectOrderReceiver::class.java).apply {
            putExtra("orderId", orderId)
        }
        val rejectPendingIntent = PendingIntent.getBroadcast(
            context,
            notifId * 2 + 2,
            rejectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Full Screen Intent / Content Intent -> Opens app
        val contentIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            putExtra("orderId", orderId)
            putExtra("autoAccept", false)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            notifId * 2,
            contentIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Determine which channel to post on (backend sends v4 or v3)
        val targetChannel = data["androidChannelId"]?.takeIf { it.isNotBlank() } ?: CHANNEL_ID_V4

        val builder = NotificationCompat.Builder(context, targetChannel)
            .setSmallIcon(smallIcon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 500, 300, 500, 300, 500))
            .setAutoCancel(true)
            .setOngoing(true)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(0, "DECLINE", rejectPendingIntent)
            .addAction(0, "ACCEPT", acceptPendingIntent)

        try {
            manager.notify(notifId, builder.build())
            Log.i(TAG, "Fallback notification posted for order $orderId on channel $targetChannel")
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException posting notification: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to post notification: ${e.message}")
        }
    }

    /**
     * Clears both our fallback notification AND the server's tray copy ("order_$orderId", 0).
     */
    fun cancel(context: Context, orderId: String?) {
        if (orderId.isNullOrBlank()) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            val notifId = notificationId(orderId)
            manager.cancel(notifId)
            // Cancel backend's tagged tray copy
            manager.cancel("order_$orderId", 0)
            Log.d(TAG, "Cancelled notification $notifId and tag order_$orderId")
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling notification for $orderId: ${e.message}")
        }
    }

    private fun createChannels(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val soundUri = Uri.parse("android.resource://${context.packageName}/raw/neworder")
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()

            for (chId in listOf(CHANNEL_ID_V4, CHANNEL_ID_V3, "new_order_channel")) {
                if (manager.getNotificationChannel(chId) == null) {
                    val channel = NotificationChannel(
                        chId,
                        CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "High importance alerts for incoming delivery requests"
                        setSound(soundUri, audioAttributes)
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 500, 300, 500, 300, 500)
                        lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                        setBypassDnd(true)
                    }
                    manager.createNotificationChannel(channel)
                }
            }
        }
    }

    private fun wakeScreen(context: Context) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "lagech:order_offer_wake"
            )
            wakeLock.acquire(15000L)
        } catch (e: Exception) {
            Log.e(TAG, "WakeLock error: ${e.message}")
        }
    }
}
