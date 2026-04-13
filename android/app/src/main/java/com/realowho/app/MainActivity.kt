package com.realowho.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.realowho.app.auth.MarketplaceSessionStore
import com.realowho.app.marketplace.ConversationTaskSnapshotSyncStore
import com.realowho.app.marketplace.ConversationStore
import com.realowho.app.marketplace.MarketplaceExperienceStore
import com.realowho.app.marketplace.SaleCoordinationStore
import com.realowho.app.ui.RealOWhoApp
import com.realowho.app.ui.theme.RealOWhoTheme

class MainActivity : ComponentActivity() {
    private var pendingSaleWorkspaceLaunch by mutableStateOf(false)
    private var pendingFocusedChecklistItemId by mutableStateOf<String?>(null)
    private var pendingLegalInviteCode by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val launchConfiguration = AppLaunchConfiguration.fromIntent(intent)
        pendingSaleWorkspaceLaunch = launchConfiguration.pendingSaleWorkspaceLaunch
        pendingFocusedChecklistItemId = launchConfiguration.pendingFocusedChecklistItemId
        pendingLegalInviteCode = launchConfiguration.pendingLegalInviteCode

        setContent {
            val baseLaunchConfiguration = remember {
                launchConfiguration.copy(
                    pendingSaleWorkspaceLaunch = false,
                    pendingFocusedChecklistItemId = null,
                    pendingLegalInviteCode = null
                )
            }
            val launchStateStore = remember { AppLaunchStateStore(applicationContext) }
            var hasCompletedWelcome by remember {
                mutableStateOf(
                    launchStateStore.hasCompletedWelcome() || launchConfiguration.isScreenshotMode
                )
            }
            LaunchedEffect(launchConfiguration.isScreenshotMode) {
                if (launchConfiguration.isScreenshotMode) {
                    launchStateStore.setWelcomeCompleted(true)
                    hasCompletedWelcome = true
                }
            }
            val store = remember { MarketplaceSessionStore(applicationContext, baseLaunchConfiguration) }
            val saleStore = remember { SaleCoordinationStore(applicationContext, baseLaunchConfiguration) }
            val conversationStore = remember { ConversationStore(applicationContext, baseLaunchConfiguration) }
            val marketplaceStore = remember { MarketplaceExperienceStore(applicationContext, baseLaunchConfiguration) }
            val taskSnapshotStore = remember {
                ConversationTaskSnapshotSyncStore(applicationContext, baseLaunchConfiguration)
            }

            RealOWhoTheme {
                RealOWhoApp(
                    store = store,
                    marketplaceStore = marketplaceStore,
                    saleStore = saleStore,
                    conversationStore = conversationStore,
                    taskSnapshotStore = taskSnapshotStore,
                    hasCompletedWelcome = hasCompletedWelcome,
                    onWelcomeCompleted = {
                        hasCompletedWelcome = true
                        launchStateStore.setWelcomeCompleted(true)
                        store.ensureGuestSession()
                    },
                    pendingSaleWorkspaceLaunch = pendingSaleWorkspaceLaunch,
                    onPendingSaleWorkspaceLaunchHandled = {
                        pendingSaleWorkspaceLaunch = false
                    },
                    pendingFocusedChecklistItemId = pendingFocusedChecklistItemId,
                    onPendingFocusedChecklistItemHandled = {
                        pendingFocusedChecklistItemId = null
                    },
                    pendingLegalInviteCode = pendingLegalInviteCode,
                    onPendingLegalInviteCodeHandled = {
                        pendingLegalInviteCode = null
                    }
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val launchConfiguration = AppLaunchConfiguration.fromIntent(intent)
        pendingSaleWorkspaceLaunch = launchConfiguration.pendingSaleWorkspaceLaunch
        pendingFocusedChecklistItemId = launchConfiguration.pendingFocusedChecklistItemId
        pendingLegalInviteCode = launchConfiguration.pendingLegalInviteCode
    }

    companion object {
        const val EXTRA_OPEN_SALE_WORKSPACE = "open_sale_workspace"
        const val EXTRA_FOCUSED_CHECKLIST_ITEM_ID = "focused_checklist_item_id"
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
    val initialTab: AppTab?,
    val pendingSaleWorkspaceLaunch: Boolean,
    val pendingFocusedChecklistItemId: String?,
    val pendingLegalInviteCode: String?
) {
    companion object {
        private const val EXTRA_SCREENSHOT_MODE = "screenshot_mode"
        private const val EXTRA_INITIAL_TAB = "initial_tab"
        private const val LEGAL_WORKSPACE_SCHEME = "realowho"
        private const val LEGAL_WORKSPACE_HOST = "legal-workspace"
        private const val LEGAL_WORKSPACE_CODE_QUERY = "code"

        fun fromIntent(intent: Intent?): AppLaunchConfiguration {
            val screenshotMode = intent?.getBooleanExtra(EXTRA_SCREENSHOT_MODE, false) ?: false
            val initialTab = AppTab.from(intent?.getStringExtra(EXTRA_INITIAL_TAB))
            val pendingSaleWorkspaceLaunch =
                intent?.getBooleanExtra(MainActivity.EXTRA_OPEN_SALE_WORKSPACE, false) ?: false
            val pendingFocusedChecklistItemId = intent
                ?.getStringExtra(MainActivity.EXTRA_FOCUSED_CHECKLIST_ITEM_ID)
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
            val pendingLegalInviteCode = legalInviteCodeFromUri(intent?.data)

            return AppLaunchConfiguration(
                isScreenshotMode = screenshotMode,
                initialTab = initialTab,
                pendingSaleWorkspaceLaunch = pendingSaleWorkspaceLaunch,
                pendingFocusedChecklistItemId = pendingFocusedChecklistItemId,
                pendingLegalInviteCode = pendingLegalInviteCode
            )
        }

        private fun legalInviteCodeFromUri(uri: Uri?): String? {
            if (uri == null) {
                return null
            }

            if (!uri.scheme.equals(LEGAL_WORKSPACE_SCHEME, ignoreCase = true)) {
                return null
            }

            if (!uri.host.equals(LEGAL_WORKSPACE_HOST, ignoreCase = true)) {
                return null
            }

            return uri.getQueryParameter(LEGAL_WORKSPACE_CODE_QUERY)
                ?.trim()
                ?.uppercase()
                ?.takeIf { it.isNotEmpty() }
        }
    }
}
