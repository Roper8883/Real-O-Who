package com.realowho.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.remember
import com.realowho.app.data.ReflectionStore
import com.realowho.app.ui.RealOWhoApp
import com.realowho.app.ui.theme.RealOWhoTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val launchConfiguration = AppLaunchConfiguration.fromIntent(intent)

        setContent {
            val store = remember { ReflectionStore(applicationContext, launchConfiguration) }

            RealOWhoTheme {
                RealOWhoApp(
                    store = store,
                    launchConfiguration = launchConfiguration
                )
            }
        }
    }
}

enum class AppTab(val label: String, val symbol: String) {
    TODAY("Today", "✍️"),
    ENTRIES("Entries", "📘"),
    INSIGHTS("Insights", "📊"),
    ABOUT("About", "ℹ️");

    companion object {
        fun from(rawValue: String?): AppTab? = entries.firstOrNull { tab ->
            tab.name.equals(rawValue, ignoreCase = true)
        }
    }
}

data class AppLaunchConfiguration(
    val isScreenshotMode: Boolean,
    val initialTab: AppTab?
) {
    companion object {
        private const val EXTRA_SCREENSHOT_MODE = "screenshot_mode"
        private const val EXTRA_INITIAL_TAB = "initial_tab"

        fun fromIntent(intent: Intent?): AppLaunchConfiguration {
            val screenshotMode = intent?.getBooleanExtra(EXTRA_SCREENSHOT_MODE, false) ?: false
            val initialTab = AppTab.from(intent?.getStringExtra(EXTRA_INITIAL_TAB))

            return AppLaunchConfiguration(
                isScreenshotMode = screenshotMode,
                initialTab = initialTab
            )
        }
    }
}

