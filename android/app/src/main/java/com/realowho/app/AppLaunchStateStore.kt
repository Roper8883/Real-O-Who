package com.realowho.app

import android.content.Context

private const val APP_PREFERENCES = "real-o-who-app"
private const val HAS_COMPLETED_WELCOME_KEY = "realowho.hasCompletedWelcome"

class AppLaunchStateStore(context: Context) {
    private val preferences = context.getSharedPreferences(APP_PREFERENCES, Context.MODE_PRIVATE)

    fun hasCompletedWelcome(): Boolean {
        return preferences.getBoolean(HAS_COMPLETED_WELCOME_KEY, false)
    }

    fun setWelcomeCompleted(value: Boolean = true) {
        preferences.edit()
            .putBoolean(HAS_COMPLETED_WELCOME_KEY, value)
            .apply()
    }
}

