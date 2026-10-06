package com.lagech.delivery

import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val OVERLAY_CHANNEL = "com.lagech.delivery/new_order_overlay"
    }

    private val CHANNEL = "app.fooddelivery/unlock"
    private val ONLINE_CHANNEL = "app.fooddelivery/rider_online"
    private val READINESS_CHANNEL = "app.fooddelivery/device_readiness"
    private var overlayChannel: MethodChannel? = null

    override fun onResume() {
        super.onResume()
        AppForeground.isForeground = true
        Log.d(TAG, "AppForeground.isForeground = true")
        if (intent?.getBooleanExtra("autoAccept", false) == true) {
            unlockScreen()
            dispatchAutoAcceptIfPresent(intent)
        }
    }

    override fun onPause() {
        AppForeground.isForeground = false
        Log.d(TAG, "AppForeground.isForeground = false")
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // launchMode is singleTop: setIntent is essential so Flutter reads the latest launch extras
        setIntent(intent)
        val orderId = intent.getStringExtra("orderId")
        val autoAccept = intent.getBooleanExtra("autoAccept", false)
        Log.d(TAG, "onNewIntent received with orderId=$orderId, autoAccept=$autoAccept")
        if (autoAccept) {
            unlockScreen()
            dispatchAutoAcceptIfPresent(intent)
        }
    }

    private fun dispatchAutoAcceptIfPresent(intent: Intent?) {
        val orderId = intent?.getStringExtra("orderId")
        val autoAccept = intent?.getBooleanExtra("autoAccept", false) ?: false
        if (!orderId.isNullOrBlank() && autoAccept) {
            val payload = mapOf(
                "orderId" to orderId,
                "autoAccept" to true
            )
            Log.d(TAG, "dispatchAutoAcceptIfPresent invoking onAutoAcceptOrder: $payload")
            overlayChannel?.invokeMethod("onAutoAcceptOrder", payload)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native New Order Overlay Bridge Channel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
        overlayChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeLaunchOrder" -> {
                    val currentIntent = intent
                    val orderId = currentIntent?.getStringExtra("orderId")
                    if (!orderId.isNullOrBlank()) {
                        val autoAccept = currentIntent.getBooleanExtra("autoAccept", false)
                        // Clear from intent so a future resume does not re-raise this order
                        currentIntent.removeExtra("orderId")
                            currentIntent.removeExtra("autoAccept")

                            val payload = mapOf(
                                "orderId" to orderId,
                                "autoAccept" to autoAccept
                            )
                            Log.d(TAG, "consumeLaunchOrder consumed: $payload")
                            result.success(payload)
                        } else {
                            result.success(null)
                        }
                    }

                    "takePendingRejections" -> {
                        try {
                            val prefs = getSharedPreferences(RejectOrderReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                            val rejections = prefs.getStringSet(RejectOrderReceiver.KEY_PENDING_REJECTIONS, emptySet())?.toList() ?: emptyList()
                            if (rejections.isNotEmpty()) {
                                prefs.edit().remove(RejectOrderReceiver.KEY_PENDING_REJECTIONS).apply()
                                Log.d(TAG, "takePendingRejections returning ${rejections.size} rejections: $rejections")
                            }
                            result.success(rejections)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error taking pending rejections: ${e.message}")
                            result.success(emptyList<String>())
                        }
                    }

                    "hasOverlayPermission" -> {
                        val hasPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this)
                        } else {
                            true
                        }
                        result.success(hasPerm)
                    }

                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            // Guard: only open Settings if permission is NOT already granted.
                            // Without this, the Settings screen pops up on every app resume
                            // even after the rider has allowed "Display over other apps".
                            if (Settings.canDrawOverlays(this)) {
                                Log.d(TAG, "requestOverlayPermission: already granted, skipping")
                                result.success(true)
                                return@setMethodCallHandler
                            }
                            try {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to open overlay permission settings: ${e.message}")
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    }

                    "dismissOverlay" -> {
                        NewOrderOverlay.dismiss()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        // Screen Unlock Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "unlockScreen") {
                unlockScreen()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Device Readiness Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, READINESS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "manufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> {
                        result.success(requestIgnoreBatteryOptimizations())
                    }
                    "hasAutoStartSettings" -> result.success(resolveAutoStartIntent() != null)
                    "openAutoStartSettings" -> result.success(openAutoStartSettings())
                    "openAppSettings" -> {
                        startActivitySafely(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            )
                        )
                        result.success(true)
                    }
                    // AlertPermissionFlow uses these two via READINESS_CHANNEL
                    "canDrawOverlays" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                            Settings.canDrawOverlays(this) else true
                        result.success(granted)
                    }
                    "requestOverlay" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            !Settings.canDrawOverlays(this)) {
                            try {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                        Uri.parse("package:$packageName")
                                    )
                                )
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(true) // already granted or pre-M
                        }
                    }
                    "canUseFullScreenIntent" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                            nm?.canUseFullScreenIntent() ?: true
                        } else true
                        result.success(granted)
                    }
                    "requestFullScreenIntent" -> {
                        // Android 14+ needs the user to flip a switch in Settings.
                        // On older versions it is always granted.
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                            if (nm?.canUseFullScreenIntent() == true) {
                                result.success(true)
                                return@setMethodCallHandler
                            }
                            try {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                        Uri.parse("package:$packageName")
                                    )
                                )
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Rider Online Foreground Service Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ONLINE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            RiderOnlineService.start(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        try {
                            RiderOnlineService.stop(applicationContext)
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (isIgnoringBatteryOptimizations()) return true

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val directIntent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName"),
            )
            if (startActivitySafely(directIntent)) return true
        }

        val settingsIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        return startActivitySafely(settingsIntent)
    }

    private fun resolveAutoStartIntent(): Intent? {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent().setComponent(ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity")),
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")),
            Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.entry.FunctionActivity")).setData(Uri.parse("entry:AutoStart")),
            Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            Intent().setComponent(ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListAct")),
        )

        val pm = packageManager
        return intents.firstOrNull { intent ->
            pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY).isNotEmpty()
        }
    }

    private fun openAutoStartSettings(): Boolean {
        val intent = resolveAutoStartIntent() ?: return false
        return startActivitySafely(intent)
    }

    private fun startActivitySafely(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun unlockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }
}
