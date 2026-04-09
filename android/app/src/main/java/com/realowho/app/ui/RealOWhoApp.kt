package com.realowho.app.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import com.realowho.app.auth.MarketplaceSessionStore
import com.realowho.app.marketplace.ConversationTaskSnapshotSyncStore
import com.realowho.app.marketplace.ConversationStore
import com.realowho.app.marketplace.MarketplaceExperienceStore
import com.realowho.app.marketplace.SaleCoordinationStore
import com.realowho.app.marketplace.SaleReminderScheduler
import com.realowho.app.marketplace.taskSnapshotAudienceMembers

@Composable
fun RealOWhoApp(
    store: MarketplaceSessionStore,
    marketplaceStore: MarketplaceExperienceStore,
    saleStore: SaleCoordinationStore,
    conversationStore: ConversationStore,
    taskSnapshotStore: ConversationTaskSnapshotSyncStore,
    pendingSaleWorkspaceLaunch: Boolean,
    onPendingSaleWorkspaceLaunchHandled: () -> Unit,
    pendingFocusedChecklistItemId: String?,
    onPendingFocusedChecklistItemHandled: () -> Unit,
    pendingLegalInviteCode: String?,
    onPendingLegalInviteCodeHandled: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val reminderScheduler = remember {
        SaleReminderScheduler(context.applicationContext)
    }
    var deepLinkErrorMessage by rememberSaveable { mutableStateOf<String?>(null) }
    var deepLinkInviteCode by rememberSaveable { mutableStateOf<String?>(null) }
    var didRequestNotificationPermission by rememberSaveable { mutableStateOf(false) }
    val notificationsAllowed =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        didRequestNotificationPermission = true
        if (granted && store.isAuthenticated) {
            reminderScheduler.sync(
                currentUser = store.currentUser,
                listing = saleStore.listing,
                offer = saleStore.offer,
                notificationsAllowed = true,
                taskSnapshotStore = taskSnapshotStore
            )
        }
    }

    LaunchedEffect(pendingLegalInviteCode) {
        val inviteCode = pendingLegalInviteCode?.trim()?.uppercase()
        if (inviteCode.isNullOrEmpty()) {
            return@LaunchedEffect
        }

        deepLinkInviteCode = inviteCode
        deepLinkErrorMessage = null

        try {
            val didOpen = saleStore.openLegalWorkspace(inviteCode)
            if (!didOpen) {
                deepLinkErrorMessage = "That legal workspace invite could not be found yet."
            }
        } catch (error: Exception) {
            deepLinkErrorMessage = error.message ?: "Could not open the legal workspace right now."
        } finally {
            onPendingLegalInviteCodeHandled()
        }
    }

    LaunchedEffect(pendingSaleWorkspaceLaunch, store.isAuthenticated) {
        if (!pendingSaleWorkspaceLaunch) {
            return@LaunchedEffect
        }

        saleStore.closeLegalWorkspace()
        onPendingSaleWorkspaceLaunchHandled()
    }

    LaunchedEffect(store.isAuthenticated) {
        if (!store.isAuthenticated) {
            reminderScheduler.clearAll()
            return@LaunchedEffect
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !notificationsAllowed &&
            !didRequestNotificationPermission
        ) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    val activeTaskSnapshotViewerId = remember(
        store.isAuthenticated,
        store.currentUser.id,
        saleStore.legalWorkspaceSession?.inviteId
    ) {
        saleStore.legalWorkspaceSession?.inviteId?.let {
            ConversationTaskSnapshotSyncStore.viewerIdForInvite(it)
        } ?: if (store.isAuthenticated) {
            ConversationTaskSnapshotSyncStore.viewerIdForUser(store.currentUser.id)
        } else {
            null
        }
    }

    val trackedTaskSnapshotViewerIds = remember(
        activeTaskSnapshotViewerId,
        saleStore.offer.id,
        saleStore.offer.invites,
        saleStore.offer.buyerId,
        saleStore.offer.sellerId
    ) {
        buildSet {
            activeTaskSnapshotViewerId?.let(::add)
            saleStore.offer.taskSnapshotAudienceMembers.mapTo(this) { it.viewerId }
        }.toList().sorted()
    }

    val reminderTaskSnapshotFingerprint = taskSnapshotStore.notificationFingerprint(trackedTaskSnapshotViewerIds)

    LaunchedEffect(
        store.isAuthenticated,
        store.currentUser.id,
        saleStore.offer,
        saleStore.listing,
        notificationsAllowed,
        reminderTaskSnapshotFingerprint
    ) {
        if (!store.isAuthenticated) {
            reminderScheduler.clearAll()
            return@LaunchedEffect
        }

        reminderScheduler.sync(
            currentUser = store.currentUser,
            listing = saleStore.listing,
            offer = saleStore.offer,
            notificationsAllowed = notificationsAllowed,
            taskSnapshotStore = taskSnapshotStore
        )
    }

    LaunchedEffect(trackedTaskSnapshotViewerIds) {
        taskSnapshotStore.refresh(trackedTaskSnapshotViewerIds)
    }

    Surface(modifier = modifier) {
        if (saleStore.legalWorkspaceSession != null) {
            LegalWorkspaceScreen(
                saleStore = saleStore,
                conversationStore = conversationStore,
                taskSnapshotStore = taskSnapshotStore
            )
        } else if (store.isAuthenticated) {
            MarketplaceHomeScreen(
                store = store,
                marketplaceStore = marketplaceStore,
                saleStore = saleStore,
                conversationStore = conversationStore,
                taskSnapshotStore = taskSnapshotStore,
                reminderScheduler = reminderScheduler,
                focusedChecklistItemId = pendingFocusedChecklistItemId,
                onFocusedChecklistReminderResolved = { checklistItemId ->
                    if (pendingFocusedChecklistItemId == checklistItemId) {
                        onPendingFocusedChecklistItemHandled()
                    }
                }
            )
        } else {
            AuthenticationScreen(
                store = store,
                saleStore = saleStore,
                prefilledLegalInviteCode = deepLinkInviteCode,
                externalErrorMessage = deepLinkErrorMessage
            )
        }
    }
}
