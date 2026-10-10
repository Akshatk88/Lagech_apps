package com.lagech.restaurant

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Rings until the restaurant accepts or rejects.
 *
 * Plays exactly ONCE in a continuous loop until explicitly stopped on Accept/Reject/Dismiss.
 * Deduplicates across all order ID representations (MongoId vs displayId vs orderId) so that
 * simultaneous Socket.IO and FCM events NEVER restart or overlap the ringtone.
 */
object NewOrderRingtone {

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var focusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null

    /** All order IDs (aliases, MongoId, readable orderNumber) currently ringing */
    private val currentRingingIds = mutableSetOf<String>()

    private val handler = Handler(Looper.getMainLooper())
    private val stopRunnable = Runnable { stop(null) }

    /**
     * Hard ceiling, independent of every other stop path.
     */
    private const val MAX_RING_MS = 120_000L

    private const val TAG = "NewOrderRingtone"

    @Synchronized
    fun start(context: Context, orderIds: Collection<String>, ringMillis: Long) {
        val filteredIds = orderIds.filter { it.isNotBlank() }

        // If already ringing for this exact same order (or any of its ID aliases), do NOT restart or stutter!
        if (player != null && (filteredIds.isEmpty() || currentRingingIds.any { filteredIds.contains(it) })) {
            Log.i(TAG, "Already ringing for order aliases: $filteredIds (active: $currentRingingIds) — keeping current ringtone playing smoothly")
            currentRingingIds.addAll(filteredIds)
            return
        }

        // A DIFFERENT order replaces the current ring rather than layering a second player on top
        stopInternal()

        currentRingingIds.addAll(filteredIds)
        val primaryId = filteredIds.firstOrNull() ?: "new_order"
        Log.i(TAG, "Starting single clean ring for $primaryId (aliases: $filteredIds, ${ringMillis}ms)")

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        requestAudioFocus(context, attributes)

        try {
            val p = MediaPlayer.create(context, R.raw.tujh_bin1, attributes, audioManager?.generateAudioSessionId() ?: 0)
                ?: MediaPlayer.create(context, R.raw.tujh_bin1)
            if (p != null) {
                p.setAudioAttributes(attributes)
                p.isLooping = true
                p.setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "ringtone error what=$what extra=$extra")
                    false
                }
                p.start()
                player = p
                Log.i(TAG, "Ringtone started successfully (single clean loop)")
            } else {
                val soundUri = Uri.parse("android.resource://${context.packageName}/raw/tujh_bin1")
                player = MediaPlayer().apply {
                    setAudioAttributes(attributes)
                    setDataSource(context, soundUri)
                    isLooping = true
                    setOnPreparedListener {
                        Log.i(TAG, "ringtone prepared via URI fallback, starting loop")
                        it.start()
                    }
                    setOnErrorListener { _, what, extra ->
                        Log.e(TAG, "ringtone fallback error what=$what extra=$extra")
                        false
                    }
                    prepareAsync()
                }
            }
        } catch (t: Throwable) {
            Log.e(TAG, "ringtone failed to start", t)
            player = null
        }

        startVibration(context)

        handler.removeCallbacks(stopRunnable)
        handler.postDelayed(stopRunnable, ringMillis.coerceIn(5_000L, MAX_RING_MS))
    }

    @Synchronized
    fun start(context: Context, orderId: String, ringMillis: Long) {
        start(context, listOf(orderId), ringMillis)
    }

    /**
     * Stop the ringing unconditionally.
     * Any decision (Accept, Reject, Dismiss, or manual stop) immediately silences the audio.
     */
    @Synchronized
    fun stop(orderId: String? = null) {
        stopInternal()
    }

    @Synchronized
    fun isRinging(): Boolean = player != null

    @Synchronized
    fun isRingingFor(ids: Collection<String>): Boolean {
        if (player == null) return false
        if (ids.isEmpty()) return true
        return currentRingingIds.any { ids.contains(it) }
    }

    private fun stopInternal() {
        handler.removeCallbacks(stopRunnable)
        currentRingingIds.clear()

        try {
            player?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Throwable) {
        }
        player = null

        try {
            vibrator?.cancel()
        } catch (_: Throwable) {
        }
        vibrator = null

        abandonAudioFocus()
    }

    private fun startVibration(context: Context) {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager =
                    context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            val pattern = longArrayOf(0, 600, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (_: Throwable) {
            vibrator = null
        }
    }

    private fun requestAudioFocus(context: Context, attributes: AudioAttributes) {
        try {
            val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager = manager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val request = AudioFocusRequest
                    .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(attributes)
                    .setAcceptsDelayedFocusGain(true)
                    .build()
                focusRequest = request
                manager.requestAudioFocus(request)
            } else {
                @Suppress("DEPRECATION")
                manager.requestAudioFocus(
                    null,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
                )
            }
        } catch (_: Throwable) {
            audioManager = null
        }
    }

    private fun abandonAudioFocus() {
        try {
            val manager = audioManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { manager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                manager.abandonAudioFocus(null)
            }
        } catch (_: Throwable) {
        }
        focusRequest = null
        audioManager = null
    }
}
