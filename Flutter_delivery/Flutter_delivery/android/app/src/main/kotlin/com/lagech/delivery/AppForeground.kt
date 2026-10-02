package com.lagech.delivery

/**
 * Tracks whether the Flutter activity is currently in foreground or background.
 * Updated in MainActivity's onResume / onPause.
 */
object AppForeground {
    @Volatile
    var isForeground: Boolean = false
}
