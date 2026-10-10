package com.lagech.restaurant

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val ORDER_ACTION_CHANNEL = "app.foodrestaurant/new_order_action"
    private val TAG = "MainActivity"

    /**
     * Held so a decision arriving from the notification can be pushed at Dart
     * immediately, instead of waiting for the next time Dart happens to poll.
     */
    private var actionChannel: MethodChannel? = null

    override fun onResume() {
        super.onResume()
        AppForeground.isForeground = true
        Log.d(TAG, "AppForeground.isForeground = true")
        if (PendingOrderAction.hasPending()) {
            actionChannel?.invokeMethod("onOrderAction", PendingOrderAction.consume())
        }
    }

    override fun onPause() {
        AppForeground.isForeground = false
        Log.d(TAG, "AppForeground.isForeground = false")
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ORDER_ACTION_CHANNEL)
            .also { channel ->
                actionChannel = channel

                // Lets a Reject pressed on the notification reach Dart without the app
                // being brought to the foreground. invokeMethod must be called from
                // the main thread; the receiver runs there, but the post keeps that
                // true regardless of who calls set().
                PendingOrderAction.listener = { action ->
                    runOnUiThread { actionChannel?.invokeMethod("onOrderAction", action) }
                }

                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        // Read-and-clear. Dart calls this on start and on resume, which
                        // is the path that matters when the app was killed: no engine
                        // existed when the button was pressed, so the decision has to
                        // wait for Dart rather than the other way round.
                        "consumePendingAction" -> result.success(PendingOrderAction.consume())
                        "hasPendingAction" -> result.success(PendingOrderAction.hasPending())
                        "dismissOrderAlert" -> {
                            NewOrderNotifier.dismiss(
                                applicationContext,
                                call.argument<String>("orderId"),
                            )
                            result.success(true)
                        }
                        // Used when the order is answered inside the app, so the alert
                        // and its ringing stop there too.
                        "stopAlertSound" -> {
                            NewOrderRingtone.stop(null)
                            result.success(true)
                        }
                        "startAlertSound" -> {
                            val orderId = call.argument<String>("orderId") ?: "new_order"
                            val ringMillis = (call.argument<Number>("ringMillis")?.toLong()) ?: 60000L
                            NewOrderRingtone.start(applicationContext, orderId, ringMillis)
                            result.success(true)
                        }
                        "showOrderAlert" -> {
                            val data = call.argument<Map<String, Any>>("data")
                            if (data != null) {
                                val stringMap = data.mapValues { it.value.toString() }
                                NewOrderNotifier.show(applicationContext, stringMap)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }

    /**
     * A decision taken on the notification while the app was already running. onCreate
     * has come and gone, so Dart would not otherwise learn about it until its next
     * poll — push it now so Accept feels immediate.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (PendingOrderAction.hasPending()) {
            actionChannel?.invokeMethod("onOrderAction", PendingOrderAction.consume())
        }
    }

    /** The engine is going away; a stale listener would invoke a dead channel. */
    override fun onDestroy() {
        PendingOrderAction.listener = null
        actionChannel = null
        super.onDestroy()
    }
}
