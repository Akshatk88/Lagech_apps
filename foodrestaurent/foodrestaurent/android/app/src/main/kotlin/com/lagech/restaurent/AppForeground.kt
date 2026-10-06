package com.lagech.restaurent

/**
 * Tracks whether the Flutter Activity is currently in the foreground (active on screen)
 * or in the background / killed.
 * Updated in MainActivity's onResume and onPause.
 */
object AppForeground {
    @Volatile
    var isForeground: Boolean = false
}
