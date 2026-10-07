package com.lagech.vendor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.concurrent.ConcurrentHashMap

/**
 * Posts the new-order alert with Accept and Reject action buttons and fullScreenIntent.
 *
 * Sound is handled EXCLUSIVELY by NewOrderRingtone on the USAGE_ALARM stream, while
 * this notification is set to silent so Android does NOT play a competing sound copy.
 */
object NewOrderNotifier {

    private const val TAG = "NewOrderNotifier"

    /**
     * Bumped to v6 so Android OS resets sound to null (silent channel).
     * Audio is exclusively played by NewOrderRingtone in a clean single loop.
     */
    private const val CHANNEL_ID = "new_order_ringing_v6"
    private const val CHANNEL_NAME = "New order alerts"

    /**
     * Orders that arrive already confirmed (the delivery partner confirms them) are
     * a plain heads-up with the system's normal notification sound: nothing to accept
     * or reject, so no alarm loop and no full-screen takeover.
     */
    private const val CONFIRMED_CHANNEL_ID = "order_confirmed_v1"
    private const val CONFIRMED_CHANNEL_NAME = "Confirmed orders"

    const val ACTION_ACCEPT = "com.lagech.vendor.NEW_ORDER_ACCEPT"
    const val ACTION_REJECT = "com.lagech.vendor.NEW_ORDER_REJECT"
    const val EXTRA_ORDER_ID = "orderId"

    /** Maps all aliases (MongoId, readable orderNumber, displayId) to the canonical order ID */
    private val aliasToCanonical = ConcurrentHashMap<String, String>()

    /** Keyed on the order so a withdrawal can cancel exactly this alert. */
    fun notificationId(orderId: String?): Int =
        (orderId ?: "new_order").hashCode() and 0x7fffffff

    /** Extracts a canonical ID consistent between Socket.IO and FCM */
    fun canonicalOrderId(allIds: Collection<String>, data: Map<String, String>): String {
        val mongoId = data["orderMongoId"]?.takeIf { it.isNotBlank() }
            ?: data["_id"]?.takeIf { it.isNotBlank() }
            ?: allIds.firstOrNull { it.length == 24 && it.all { c -> c.isDigit() || c in 'a'..'f' || c in 'A'..'F' } }
        if (mongoId != null) return mongoId

        return data["orderId"]?.takeIf { it.isNotBlank() }
            ?: data["orderDisplayId"]?.takeIf { it.isNotBlank() }
            ?: allIds.firstOrNull()
            ?: "new_order"
    }

    /**
     * False only when the push says `needsAcceptance` is "false" — the order arrived
     * already confirmed. A missing field (older server) keeps the Accept/Reject alarm.
     */
    fun needsAcceptance(data: Map<String, String>): Boolean =
        data["needsAcceptance"]?.trim()?.lowercase() != "false"

    fun show(context: Context, data: Map<String, String>) {
        val allIds = NewOrderMessagingService.allOrderIdsOf(data)
        val canonicalId = canonicalOrderId(allIds, data)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Map every alias to the canonical ID so dismiss/cancel always hits the same notification
        for (id in allIds) {
            aliasToCanonical[id] = canonicalId
        }
        aliasToCanonical[canonicalId] = canonicalId

        // Record in FCM deduplication cache so subsequent FCM/Socket events don't duplicate
        NewOrderMessagingService.recordAlert(allIds)

        // Already confirmed: no overlay (it carries Accept/Reject and starts the ring),
        // no full-screen intent, no looping ringtone — just a normal notification.
        if (!needsAcceptance(data)) {
            postConfirmedNotification(context, manager, data, canonicalId)
            return
        }

        val ringMillis = expiryMillis(data)

        // Unlocked and outside the app: the overlay card, as on the delivery app. The
        // in-app dialog covers the foreground, and the lock screen stays with the
        // full-screen notification below, which an overlay cannot draw over.
        if (!AppForeground.isForeground && NewOrderOverlay.canShow(context)) {
            wakeScreen(context)
            NewOrderOverlay.show(context, data, canonicalId, allIds, ringMillis) {
                postNotification(context, manager, data, canonicalId, allIds, ringMillis)
            }
            return
        }

        postNotification(context, manager, data, canonicalId, allIds, ringMillis)
    }

    private fun postNotification(
        context: Context,
        manager: NotificationManager,
        data: Map<String, String>,
        canonicalId: String,
        allIds: List<String>,
        ringMillis: Long,
    ) {
        createChannel(context, manager)
        wakeScreen(context)

        val title = data["title"]?.takeIf { it.isNotBlank() } ?: "New order received"
        val body = data["body"]?.takeIf { it.isNotBlank() } ?: buildBody(data)
        val notifId = notificationId(canonicalId)

        val notification: Notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            // Silent notification because NewOrderRingtone handles the loud looping audio
            .setSilent(true)
            .setSound(null)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(openAppIntent(context, canonicalId), true)
            .setContentIntent(openAppIntent(context, canonicalId))
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Reject",
                actionIntent(context, ACTION_REJECT, canonicalId),
            )
            .addAction(
                android.R.drawable.ic_menu_send,
                "Accept",
                actionIntent(context, ACTION_ACCEPT, canonicalId),
            )
            .setTimeoutAfter(ringMillis + 10_000)
            .build()

        manager.notify(notifId, notification)
        Log.i(TAG, "Notification posted for canonicalId: $canonicalId (notifId: $notifId)")

        // Start looping ringtone (MediaPlayer) with all alias IDs
        NewOrderRingtone.start(context, allIds.ifEmpty { listOf(canonicalId) }, ringMillis)
    }

    /**
     * Plain high-priority notification for an order that is already confirmed. Same
     * notification id as the alarm alert, so dismiss() and the existing cancel paths
     * still find it; tapping opens the app on the order with the same extras.
     */
    private fun postConfirmedNotification(
        context: Context,
        manager: NotificationManager,
        data: Map<String, String>,
        canonicalId: String,
    ) {
        createConfirmedChannel(manager)

        val title = data["title"]?.takeIf { it.isNotBlank() } ?: "Order confirmed"
        val body = data["body"]?.takeIf { it.isNotBlank() }
            ?: "Order is confirmed. Please start preparing."
        val notifId = notificationId(canonicalId)

        val notification: Notification = NotificationCompat.Builder(context, CONFIRMED_CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            // Pre-O devices: one normal sound (the channel covers O and up).
            .setDefaults(NotificationCompat.DEFAULT_SOUND)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(context, canonicalId))
            .build()

        manager.notify(notifId, notification)
        Log.i(TAG, "Confirmed-order notification posted for canonicalId: $canonicalId (notifId: $notifId)")
    }

    /** Take the alert down and stop the ring — order taken elsewhere, or cancelled. */
    fun dismiss(context: Context, orderId: String?) {
        NewOrderRingtone.stop(null)
        NewOrderOverlay.dismiss(orderId?.let { aliasToCanonical[it] ?: it })
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (orderId != null) {
            val canonical = aliasToCanonical[orderId] ?: orderId
            manager.cancel(notificationId(canonical))
            manager.cancel(notificationId(orderId))
        }
    }

    /** Last-resort minimal alert */
    fun showFallback(context: Context, data: Map<String, String>) {
        val allIds = NewOrderMessagingService.allOrderIdsOf(data)
        val canonicalId = canonicalOrderId(allIds, data)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!needsAcceptance(data)) {
            postConfirmedNotification(context, manager, data, canonicalId)
            return
        }
        createChannel(context, manager)

        val notifId = notificationId(canonicalId)
        manager.notify(
            notifId,
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(data["title"]?.takeIf { it.isNotBlank() } ?: "New order received")
                .setContentText(buildBody(data))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setSilent(true)
                .setSound(null)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setContentIntent(openAppIntent(context, canonicalId))
                .build(),
        )

        NewOrderRingtone.start(context, allIds.ifEmpty { listOf(canonicalId) }, expiryMillis(data))
    }

    private fun actionIntent(context: Context, action: String, orderId: String): PendingIntent {
        val intent = Intent(context, NewOrderActionReceiver::class.java).apply {
            this.action = action
            putExtra(EXTRA_ORDER_ID, orderId)
        }
        return PendingIntent.getBroadcast(
            context,
            (action + orderId).hashCode() and 0x7fffffff,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openAppIntent(context: Context, orderId: String): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(EXTRA_ORDER_ID, orderId)
            }
            ?: Intent()
        return PendingIntent.getActivity(
            context,
            notificationId(orderId),
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        // Delete legacy channels that played sound so they don't produce audio artifacts
        val legacyChannels = listOf(
            "new_order_ringing_v5",
            "new_order_ringing_v4",
            "new_order_channel",
            "new_order_channel_v3",
            "new_order_ringing_v3"
        )
        for (legacyId in legacyChannels) {
            try {
                if (manager.getNotificationChannel(legacyId) != null) {
                    manager.deleteNotificationChannel(legacyId)
                }
            } catch (_: Throwable) {}
        }

        // Create the clean v6 channel with NO notification sound (audio handled by NewOrderRingtone)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "High priority alarm alerts for incoming orders."
                setSound(null, null) // Silent! NewOrderRingtone handles the ringtone
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 250, 500, 250, 500)
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(true)
            }
            manager.createNotificationChannel(channel)
        }
    }

    /** High-importance channel with the system's default notification sound. */
    private fun createConfirmedChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CONFIRMED_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CONFIRMED_CHANNEL_ID,
            CONFIRMED_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Orders already confirmed by the delivery partner."
            // No setSound(): the channel keeps the default notification sound, played once.
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun wakeScreen(context: Context) {
        try {
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (power.isInteractive) return

            @Suppress("DEPRECATION")
            val lock = power.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "lagech:new_order",
            )
            lock.acquire(10_000L)
        } catch (_: Throwable) {
        }
    }

    private fun expiryMillis(data: Map<String, String>): Long {
        val seconds = (data["expiresInSeconds"] ?: data["acceptTimeoutSeconds"])
            ?.toLongOrNull()
            ?.coerceIn(15, 300)
            ?: 60
        return seconds * 1000
    }

    private fun buildBody(data: Map<String, String>): String {
        val parts = listOfNotNull(
            data["customerName"]?.takeIf { it.isNotBlank() }?.let { "Customer: $it" },
            data["itemCount"]?.takeIf { it.isNotBlank() }?.let { "$it item(s)" },
            // The restaurant's earning after commission; the customer's total only
            // from an older server that does not send it.
            data["restaurantEarning"]?.takeIf { it.isNotBlank() }?.let { "You earn: Rs.$it" }
                ?: (data["total"] ?: data["amount"])?.takeIf { it.isNotBlank() }?.let { "Total: Rs.$it" },
        )
        return if (parts.isEmpty()) "Tap to view the order" else parts.joinToString(" · ")
    }
}
