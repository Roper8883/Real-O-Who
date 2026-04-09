package com.realowho.app.ui

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.ui.window.Dialog
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircleOutline
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Gavel
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.realowho.app.auth.MarketplaceSessionStore
import com.realowho.app.auth.MarketplaceUserProfile
import com.realowho.app.auth.UserRole
import com.realowho.app.marketplace.ConversationStore
import com.realowho.app.marketplace.ConversationTaskSnapshotSyncStore
import com.realowho.app.marketplace.ConversationThread
import com.realowho.app.marketplace.ConversationMessage
import com.realowho.app.marketplace.ConversationSaleTaskTarget
import com.realowho.app.marketplace.ContractPacket
import com.realowho.app.marketplace.LegalInviteRole
import com.realowho.app.marketplace.LegalProfessional
import com.realowho.app.marketplace.LegalSelection
import com.realowho.app.marketplace.MarketplaceExperienceStore
import com.realowho.app.marketplace.MarketplaceListing
import com.realowho.app.marketplace.MarketplacePropertyType
import com.realowho.app.marketplace.MarketplaceSavedSearch
import com.realowho.app.marketplace.SaleCoordinationStore
import com.realowho.app.marketplace.SaleDocument
import com.realowho.app.marketplace.SaleInviteManagementAction
import com.realowho.app.marketplace.SaleListing
import com.realowho.app.marketplace.SaleOffer
import com.realowho.app.marketplace.SaleOfferStatus
import com.realowho.app.marketplace.SaleDocumentRenderer
import com.realowho.app.marketplace.SaleReminderScheduler
import com.realowho.app.marketplace.SaleTaskLiveSnapshot
import com.realowho.app.marketplace.SaleTaskLiveSnapshotTone
import com.realowho.app.marketplace.SaleTaskSnapshotAudienceMember
import com.realowho.app.marketplace.SaleWorkspaceInvite
import com.realowho.app.marketplace.SaleUpdateKind
import com.realowho.app.marketplace.SaleUpdateMessage
import com.realowho.app.marketplace.SellerOfferAction
import com.realowho.app.marketplace.hasBeenShared
import com.realowho.app.marketplace.isExpired
import com.realowho.app.marketplace.needsFollowUp
import com.realowho.app.marketplace.isRevoked
import com.realowho.app.marketplace.isUnavailable
import com.realowho.app.marketplace.liveTaskSnapshot
import com.realowho.app.marketplace.nextActionSummary
import com.realowho.app.marketplace.taskSnapshotAudienceMembers
import com.realowho.app.marketplace.taskSnapshotId
import com.realowho.app.marketplace.reminderSummary
import com.realowho.app.marketplace.settlementChecklist
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private object MarketplaceLinks {
    const val WEBSITE = "https://roper8883.github.io/Real-O-Who/real-o-who/"
    const val PRIVACY = "https://roper8883.github.io/Real-O-Who/real-o-who/privacy-policy/"
    const val TERMS = "https://roper8883.github.io/Real-O-Who/real-o-who/terms-of-use/"
    const val SUPPORT = "https://roper8883.github.io/Real-O-Who/real-o-who/support/"
}

private data class DemoAccountShortcut(
    val label: String,
    val accountName: String,
    val email: String,
    val password: String
)

private val demoAccountShortcuts = listOf(
    DemoAccountShortcut(
        label = "Use Demo Buyer",
        accountName = "Noah Chen",
        email = "noah@realowho.app",
        password = "HouseDeal123!"
    ),
    DemoAccountShortcut(
        label = "Use Demo Seller",
        accountName = "Mason Wright",
        email = "mason@realowho.app",
        password = "HouseDeal123!"
    )
)

private data class MarketplaceSearchFilters(
    val query: String = "",
    val suburb: String = "",
    val minimumBedroomsText: String = "",
    val maximumPriceText: String = "",
    val propertyTypes: Set<MarketplacePropertyType> = emptySet()
) {
    val minimumBedrooms: Int
        get() = minimumBedroomsText.filter(Char::isDigit).toIntOrNull() ?: 0

    val maximumPrice: Int?
        get() = maximumPriceText.filter(Char::isDigit).toIntOrNull()
}

private enum class FocusedChecklistActionType {
    SEARCH_LEGAL_REPS,
    SHARE_INVITE,
    REGENERATE_INVITE,
    SIGN_CONTRACT
}

private data class FocusedChecklistActionPrompt(
    val title: String,
    val message: String,
    val buttonLabel: String,
    val action: FocusedChecklistActionType,
    val inviteRole: LegalInviteRole? = null
)

private sealed interface ReminderTaskDestination {
    data object LegalSearch : ReminderTaskDestination
    data class InviteManagement(
        val role: LegalInviteRole,
        val preferredAction: FocusedChecklistActionType
    ) : ReminderTaskDestination
    data object ContractSigning : ReminderTaskDestination
}

@Composable
fun MarketplaceHomeScreen(
    store: MarketplaceSessionStore,
    marketplaceStore: MarketplaceExperienceStore,
    saleStore: SaleCoordinationStore,
    conversationStore: ConversationStore,
    taskSnapshotStore: ConversationTaskSnapshotSyncStore,
    reminderScheduler: SaleReminderScheduler,
    focusedChecklistItemId: String? = null,
    onFocusedChecklistReminderResolved: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val user = store.currentUser
    val account = store.currentAccount
    val saleListing = saleStore.listing
    val saleOffer = saleStore.offer
    val counterpart = saleStore.counterpartFor(user)
    val conversation = conversationStore.threadFor(saleListing.id, user.id, counterpart.id)
    val mySelection = saleStore.currentSelection(user.role)
    val counterpartSelection = saleStore.counterpartSelection(user.role)
    val taskSnapshotViewerId = remember(user.id) {
        ConversationTaskSnapshotSyncStore.viewerIdForUser(user.id)
    }

    var filters by remember(user.id) {
        mutableStateOf(
            MarketplaceSearchFilters(
                suburb = user.suburb.substringBefore(",").trim()
            )
        )
    }
    var savedSearchTitle by remember(user.id) { mutableStateOf("") }
    var legalResults by remember(saleListing.id, user.id) { mutableStateOf(emptyList<LegalProfessional>()) }
    var isLoadingLegalResults by remember(saleListing.id, user.id) { mutableStateOf(false) }
    var legalSearchError by remember(saleListing.id, user.id) { mutableStateOf<String?>(null) }
    var noticeMessage by remember(user.id) { mutableStateOf<String?>(null) }
    var messageDraft by remember(user.id) { mutableStateOf("") }
    var offerAmountDraft by remember(user.id) { mutableStateOf(saleOffer.amount.toString()) }
    var offerConditionsDraft by remember(user.id) { mutableStateOf(saleOffer.conditions) }
    var isSubmittingOffer by remember(user.id) { mutableStateOf(false) }
    var activeReminderTask by remember(user.id, focusedChecklistItemId) {
        mutableStateOf<ReminderTaskDestination?>(null)
    }
    var autoOpenedReminderActionKey by remember(user.id) { mutableStateOf<String?>(null) }
    var reminderMetadataVersion by remember(user.id, focusedChecklistItemId) { mutableStateOf(0) }
    var messageFocusedChecklistItemId by remember(user.id) { mutableStateOf<String?>(null) }

    val effectiveFocusedChecklistItemId = messageFocusedChecklistItemId ?: focusedChecklistItemId

    fun launchLegalSearch() {
        coroutineScope.launch {
            isLoadingLegalResults = true
            legalSearchError = null
            runCatching {
                saleStore.searchLegalProfessionals()
            }.onSuccess { professionals ->
                legalResults = professionals
            }.onFailure { error ->
                legalResults = emptyList()
                legalSearchError = error.message ?: "Local legal search is unavailable right now."
            }
            isLoadingLegalResults = false
        }
    }

    fun resolveFocusedReminder(
        vararg itemIds: String,
        actionTitle: String = "Reminder completed"
    ) {
        val focusedItemId = effectiveFocusedChecklistItemId ?: return
        if (focusedItemId !in itemIds) {
            return
        }

        activeReminderTask = null
        if (messageFocusedChecklistItemId == focusedItemId) {
            messageFocusedChecklistItemId = null
        }
        val reminderOutcome = saleStore.recordReminderTimelineActivity(
            checklistItemId = focusedItemId,
            actionTitle = actionTitle,
            triggeredBy = user
        )
        coroutineScope.launch {
            saleStore.syncToBackend()
            conversationStore.sendMessage(
                listing = saleListing,
                sender = user,
                recipient = counterpart,
                body = reminderOutcome.threadMessage,
                isSystem = true,
                saleTaskTarget = ConversationSaleTaskTarget(
                    listingId = saleListing.id,
                    offerId = saleOffer.id,
                    checklistItemId = focusedItemId
                )
            )
        }
        reminderMetadataVersion += 1
        reminderScheduler.clearReminder(
            offerId = saleOffer.id,
            checklistItemId = focusedItemId,
            actionTitle = actionTitle
        )
        onFocusedChecklistReminderResolved(focusedItemId)
    }

    fun snoozeFocusedReminder() {
        val focusedItemId = effectiveFocusedChecklistItemId ?: return
        val snoozedUntil = System.currentTimeMillis() + 24L * 60L * 60L * 1000L
        if (messageFocusedChecklistItemId == focusedItemId) {
            messageFocusedChecklistItemId = null
        }
        val reminderOutcome = saleStore.recordReminderTimelineActivity(
            checklistItemId = focusedItemId,
            actionTitle = "Snoozed for 24 hours",
            triggeredBy = user,
            snoozedUntil = snoozedUntil
        )
        coroutineScope.launch {
            saleStore.syncToBackend()
            conversationStore.sendMessage(
                listing = saleListing,
                sender = user,
                recipient = counterpart,
                body = reminderOutcome.threadMessage,
                isSystem = true,
                saleTaskTarget = ConversationSaleTaskTarget(
                    listingId = saleListing.id,
                    offerId = saleOffer.id,
                    checklistItemId = focusedItemId
                )
            )
        }
        reminderScheduler.snoozeReminder(
            offerId = saleOffer.id,
            checklistItemId = focusedItemId,
            durationMillis = 24L * 60L * 60L * 1000L
        )
        noticeMessage = "Reminder snoozed for 24 hours."
        activeReminderTask = null
        reminderMetadataVersion += 1
        onFocusedChecklistReminderResolved(focusedItemId)
    }

    fun launchShareInvite(invite: SaleWorkspaceInvite) {
        if (!shareText(context, invite.role.title, invite.shareMessage)) {
            noticeMessage = "Could not open the invite share sheet right now."
            return
        }

        coroutineScope.launch {
            runCatching {
                saleStore.recordSaleInviteShare(
                    role = invite.role,
                    triggeredBy = user
                ) ?: throw IllegalStateException("Could not track the invite resend right now.")
            }.onSuccess { outcome ->
                saleStore.syncToBackend()
                conversationStore.sendMessage(
                    listing = saleListing,
                    sender = user,
                    recipient = counterpart,
                    body = outcome.threadMessage,
                    isSystem = true,
                    saleTaskTarget = ConversationSaleTaskTarget(
                        listingId = saleListing.id,
                        offerId = outcome.offer.id,
                        checklistItemId = "workspace-invites"
                    )
                )
                noticeMessage = outcome.noticeMessage
                resolveFocusedReminder(
                    "workspace-invites",
                    "workspace-active",
                    actionTitle = "Invite shared"
                )
            }.onFailure { error ->
                noticeMessage = error.message ?: "Could not track the invite resend right now."
            }
        }
    }

    fun launchManageInvite(invite: SaleWorkspaceInvite, action: SaleInviteManagementAction) {
        coroutineScope.launch {
            runCatching {
                saleStore.manageSaleInvite(
                    role = invite.role,
                    action = action,
                    triggeredBy = user
                ) ?: throw IllegalStateException("Could not update the legal workspace invite right now.")
            }.onSuccess { outcome ->
                saleStore.syncToBackend()
                conversationStore.sendMessage(
                    listing = saleListing,
                    sender = user,
                    recipient = counterpart,
                    body = outcome.threadMessage,
                    isSystem = true,
                    saleTaskTarget = ConversationSaleTaskTarget(
                        listingId = saleListing.id,
                        offerId = outcome.offer.id,
                        checklistItemId = "workspace-invites"
                    )
                )
                noticeMessage = outcome.noticeMessage
                resolveFocusedReminder(
                    "workspace-invites",
                    "workspace-active",
                    actionTitle = "Invite updated"
                )
            }.onFailure { error ->
                noticeMessage = error.message ?: "Could not update the legal workspace invite right now."
            }
        }
    }

    fun launchContractSigning() {
        coroutineScope.launch {
            isSubmittingOffer = true
            runCatching {
                saleStore.signContractPacket(user)
            }.onSuccess { outcome ->
                conversationStore.sendMessage(
                    listing = saleListing,
                    sender = user,
                    recipient = counterpart,
                    body = outcome.threadMessage,
                    isSystem = true,
                    saleTaskTarget = ConversationSaleTaskTarget(
                        listingId = saleListing.id,
                        offerId = outcome.offer.id,
                        checklistItemId = "contract-signatures"
                    )
                )
                saleStore.refreshFromBackend()
                noticeMessage = outcome.noticeMessage
                resolveFocusedReminder(
                    "contract-signatures",
                    actionTitle = "Contract signed"
                )
            }.onFailure { error ->
                noticeMessage = error.message ?: "Could not record the contract sign-off right now."
            }
            isSubmittingOffer = false
        }
    }

    fun selectLegalProfessional(
        professional: LegalProfessional,
        onSuccess: (() -> Unit)? = null
    ) {
        coroutineScope.launch {
            runCatching {
                saleStore.selectRepresentative(user, professional)
            }.onSuccess { result ->
                saleStore.syncToBackend()
                if (result.contractPacket != null) {
                    val buyer = if (user.role == UserRole.BUYER) user else counterpart
                    val seller = if (user.role == UserRole.SELLER) user else counterpart
                    conversationStore.sendContractPacket(
                        listing = saleListing,
                        offerId = result.offer.id,
                        buyer = buyer,
                        seller = seller,
                        packet = result.contractPacket,
                        triggeredBy = user
                    )
                }
                onSuccess?.invoke()
                noticeMessage = if (result.contractPacket != null) {
                    "Both legal representatives are now selected. Contract packet sent to both parties."
                } else {
                    "Your legal representative has been saved for this sale."
                }
                resolveFocusedReminder(
                    "buyer-representative",
                    "seller-representative",
                    "contract-packet",
                    actionTitle = "Legal representative selected"
                )
            }.onFailure { error ->
                noticeMessage = error.message ?: "Could not update the legal representative right now."
            }
        }
    }

    fun openReminderTask(prompt: FocusedChecklistActionPrompt) {
        when (prompt.action) {
            FocusedChecklistActionType.SEARCH_LEGAL_REPS -> {
                activeReminderTask = ReminderTaskDestination.LegalSearch
                if (!isLoadingLegalResults && legalResults.isEmpty()) {
                    launchLegalSearch()
                }
            }
            FocusedChecklistActionType.SHARE_INVITE -> {
                val inviteRole = prompt.inviteRole
                val invite = inviteRole?.let { saleOffer.latestInviteFor(it) }
                if (inviteRole == null || invite == null) {
                    noticeMessage = "That legal workspace invite is no longer available."
                } else {
                    launchShareInvite(invite)
                }
            }
            FocusedChecklistActionType.REGENERATE_INVITE -> {
                val inviteRole = prompt.inviteRole
                val invite = inviteRole?.let { saleOffer.latestInviteFor(it) }
                if (inviteRole == null || invite == null) {
                    noticeMessage = "That legal workspace invite is no longer available."
                } else {
                    activeReminderTask = ReminderTaskDestination.InviteManagement(
                        role = inviteRole,
                        preferredAction = FocusedChecklistActionType.REGENERATE_INVITE
                    )
                }
            }
            FocusedChecklistActionType.SIGN_CONTRACT -> {
                if (saleOffer.contractPacket == null) {
                    noticeMessage = "This contract packet is no longer available."
                } else {
                    activeReminderTask = ReminderTaskDestination.ContractSigning
                }
            }
        }
    }

    fun openSaleTaskFromMessage(target: ConversationSaleTaskTarget) {
        if (target.listingId != saleListing.id || target.offerId != saleOffer.id) {
            noticeMessage = "This sale task belongs to another property thread."
            return
        }

        messageFocusedChecklistItemId = target.checklistItemId
        val prompt = deriveFocusedChecklistActionPrompt(
            user = user,
            offer = saleOffer,
            focusedChecklistItemId = target.checklistItemId
        )

        if (prompt != null) {
            openReminderTask(prompt)
            noticeMessage = "Opened the linked sale task from the secure thread."
        } else {
            noticeMessage = "Opened the linked checklist step from the secure thread."
        }
    }

    val focusedReminderAction = deriveFocusedChecklistActionPrompt(
        user = user,
        offer = saleOffer,
        focusedChecklistItemId = effectiveFocusedChecklistItemId
    )
    val focusedReminderActivity = remember(
        saleOffer.id,
        effectiveFocusedChecklistItemId,
        reminderMetadataVersion
    ) {
        effectiveFocusedChecklistItemId?.let {
            reminderScheduler.reminderActivity(saleOffer.id, it)
        }.orEmpty()
    }
    val focusedReminderSnoozedUntil = remember(
        saleOffer.id,
        effectiveFocusedChecklistItemId,
        reminderMetadataVersion
    ) {
        effectiveFocusedChecklistItemId?.let {
            reminderScheduler.snoozedUntil(saleOffer.id, it)
        }
    }

    LaunchedEffect(user.id) {
        marketplaceStore.refreshForUser(user.id)
        saleStore.refreshFromBackend()
    }

    LaunchedEffect(user.id, saleOffer.amount, saleOffer.conditions) {
        offerAmountDraft = saleOffer.amount.toString()
        offerConditionsDraft = saleOffer.conditions
    }

    LaunchedEffect(
        effectiveFocusedChecklistItemId,
        focusedReminderAction?.action,
        focusedReminderAction?.inviteRole,
        saleOffer.id,
        saleOffer.contractPacket,
        saleOffer.invites
    ) {
        val reminderKey = listOfNotNull(
            saleOffer.id,
            effectiveFocusedChecklistItemId,
            focusedReminderAction?.action?.name,
            focusedReminderAction?.inviteRole?.name
        ).joinToString(":")

        if (focusedReminderAction == null || effectiveFocusedChecklistItemId == null || autoOpenedReminderActionKey == reminderKey) {
            return@LaunchedEffect
        }

        autoOpenedReminderActionKey = reminderKey

        when (focusedReminderAction.action) {
            FocusedChecklistActionType.SEARCH_LEGAL_REPS -> {
                activeReminderTask = ReminderTaskDestination.LegalSearch
                if (!isLoadingLegalResults && legalResults.isEmpty()) {
                    launchLegalSearch()
                }
            }
            FocusedChecklistActionType.REGENERATE_INVITE -> {
                focusedReminderAction.inviteRole?.let { role ->
                    if (saleOffer.latestInviteFor(role) != null) {
                        activeReminderTask = ReminderTaskDestination.InviteManagement(
                            role = role,
                            preferredAction = FocusedChecklistActionType.REGENERATE_INVITE
                        )
                    }
                }
            }
            FocusedChecklistActionType.SHARE_INVITE -> {
                focusedReminderAction.inviteRole?.let { role ->
                    saleOffer.latestInviteFor(role)?.let { invite ->
                        launchShareInvite(invite)
                    }
                }
            }
            FocusedChecklistActionType.SIGN_CONTRACT -> {
                if (saleOffer.contractPacket != null) {
                    activeReminderTask = ReminderTaskDestination.ContractSigning
                }
            }
        }
    }

    LaunchedEffect(user.id, saleListing.id, counterpart.id) {
        conversationStore.activateSession(
            user = user,
            counterpart = counterpart,
            listing = saleListing
        )
    }

    val filteredListings = marketplaceStore.filteredListings(
        query = filters.query,
        suburb = filters.suburb,
        minimumBedrooms = filters.minimumBedrooms,
        maximumPrice = filters.maximumPrice,
        propertyTypes = filters.propertyTypes
    )
    val savedListings = marketplaceStore.favoriteListings(user.id)
    val savedSearches = marketplaceStore.savedSearches(user.id)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFFF2F8FB),
                        Color.White
                    )
                )
            )
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                GradientHeroCard(
                    title = "Private sale marketplace",
                    body = "Browse owner-led homes, save your shortlist, and move straight into the legal workspace without paying agent commission."
                )
            }

            noticeMessage?.let { message ->
                item { NoticeCard(message = message) }
            }

            item {
                SearchFiltersCard(
                    filters = filters,
                    savedSearchTitle = savedSearchTitle,
                    onFiltersChange = { filters = it },
                    onSavedSearchTitleChange = { savedSearchTitle = it },
                    onSaveSearch = {
                        val title = savedSearchTitle.trim().ifBlank {
                            buildString {
                                append(filters.suburb.ifBlank { "Any suburb" })
                                if (filters.minimumBedrooms > 0) {
                                    append(" • ${filters.minimumBedrooms}+ beds")
                                }
                            }
                        }
                        marketplaceStore.addSavedSearch(
                            userId = user.id,
                            title = title,
                            suburb = filters.suburb,
                            minimumPrice = 0,
                            maximumPrice = filters.maximumPrice ?: 0,
                            minimumBedrooms = filters.minimumBedrooms,
                            propertyTypes = filters.propertyTypes
                        )
                        savedSearchTitle = ""
                        noticeMessage = "Saved search added for ${user.name.substringBefore(' ')}."
                    }
                )
            }

            item {
                SummaryCard(
                    title = "Shared marketplace state",
                    body = "Android is now reading the shared listing feed and saved-state backend for the signed-in account."
                ) {
                    MetricRow(label = "Listings", value = filteredListings.size.toString())
                    MetricRow(label = "Saved homes", value = savedListings.size.toString())
                    MetricRow(label = "Saved searches", value = savedSearches.size.toString())
                }
            }

            if (filteredListings.isEmpty()) {
                item {
                    SummaryCard(
                        title = "No listings matched",
                        body = "Widen the suburb, price, or bedroom filters to see more private-sale homes."
                    ) {}
                }
            } else {
                items(filteredListings, key = { listing -> listing.id }) { listing ->
                    MarketplaceListingCard(
                        listing = listing,
                        isFavorite = marketplaceStore.isFavorite(user.id, listing.id),
                        onToggleFavorite = { marketplaceStore.toggleFavorite(user.id, listing.id) }
                    )
                }
            }

            item {
                SummaryCard(
                    title = "Saved homes",
                    body = "Homes you star here now persist for the signed-in user."
                ) {}
            }

            if (savedListings.isEmpty()) {
                item {
                    SummaryCard(
                        title = "No saved homes yet",
                        body = "Tap Save Home on a listing and it will appear here."
                    ) {}
                }
            } else {
                items(savedListings, key = { listing -> listing.id }) { listing ->
                    MarketplaceListingCard(
                        listing = listing,
                        isFavorite = true,
                        onToggleFavorite = { marketplaceStore.toggleFavorite(user.id, listing.id) }
                    )
                }
            }

            item {
                SummaryCard(
                    title = "Saved searches",
                    body = "Saved searches are synced for the current account and can be reapplied instantly."
                ) {}
            }

            if (savedSearches.isEmpty()) {
                item {
                    SummaryCard(
                        title = "No saved searches yet",
                        body = "Create one from the filters above and it will show up here."
                    ) {}
                }
            } else {
                items(savedSearches, key = { search -> search.id }) { search ->
                    SavedSearchCard(
                        search = search,
                        onApply = {
                            filters = MarketplaceSearchFilters(
                                suburb = search.suburb,
                                minimumBedroomsText = search.minimumBedrooms.takeIf { it > 0 }?.toString().orEmpty(),
                                maximumPriceText = search.maximumPrice.takeIf { it > 0 }?.toString().orEmpty(),
                                propertyTypes = search.propertyTypes.toSet()
                            )
                            noticeMessage = "Applied saved search: ${search.title}."
                        },
                        onToggleAlerts = {
                            marketplaceStore.toggleSavedSearchAlerts(user.id, search.id)
                        }
                    )
                }
            }

            focusedReminderAction?.let { prompt ->
                item {
                    FocusedChecklistActionCard(
                        prompt = prompt,
                        snoozedUntilMillis = focusedReminderSnoozedUntil,
                        activityEntries = focusedReminderActivity,
                        onRunAction = { openReminderTask(prompt) },
                        onSnooze = { snoozeFocusedReminder() }
                    )
                }
            }

            item {
                SaleWorkspaceCard(
                    user = user,
                    listing = saleListing,
                    offer = saleOffer,
                    focusedChecklistItemId = effectiveFocusedChecklistItemId,
                    offerAmountDraft = offerAmountDraft,
                    offerConditionsDraft = offerConditionsDraft,
                    isSubmittingOffer = isSubmittingOffer,
                    onOfferAmountChange = { offerAmountDraft = it.filter(Char::isDigit) },
                    onOfferConditionsChange = { offerConditionsDraft = it },
                    onSubmitOffer = {
                        val amount = offerAmountDraft.filter(Char::isDigit).toIntOrNull()
                        if (amount == null || amount <= 0) {
                            noticeMessage = "Enter a valid offer amount before sending."
                            return@SaleWorkspaceCard
                        }

                        coroutineScope.launch {
                            isSubmittingOffer = true
                            runCatching {
                                saleStore.submitOffer(
                                    user = user,
                                    amount = amount,
                                    conditions = offerConditionsDraft
                                )
                            }.onSuccess { outcome ->
                                conversationStore.sendMessage(
                                    listing = saleListing,
                                    sender = user,
                                    recipient = counterpart,
                                    body = outcome.threadMessage,
                                    isSystem = true
                                )

                                outcome.contractPacket?.let { packet ->
                                conversationStore.sendContractPacket(
                                    listing = saleListing,
                                    offerId = outcome.offer.id,
                                    buyer = user,
                                    seller = counterpart,
                                    packet = packet,
                                    triggeredBy = user
                                    )
                                }

                                saleStore.refreshFromBackend()
                                noticeMessage = if (outcome.isRevision) {
                                    "Offer updated and synced to the shared sale workspace."
                                } else {
                                    "Offer submitted and synced to the shared sale workspace."
                                }
                            }.onFailure { error ->
                                noticeMessage = error.message ?: "Could not send the offer right now."
                            }
                            isSubmittingOffer = false
                        }
                    },
                    onSellerAction = { action ->
                        val amount = offerAmountDraft.filter(Char::isDigit).toIntOrNull()
                        if (amount == null || amount <= 0) {
                            noticeMessage = "Enter a valid amount before sending a seller response."
                            return@SaleWorkspaceCard
                        }

                        coroutineScope.launch {
                            isSubmittingOffer = true
                            runCatching {
                                saleStore.respondToOffer(
                                    user = user,
                                    action = action,
                                    amount = amount,
                                    conditions = offerConditionsDraft
                                )
                            }.onSuccess { outcome ->
                                conversationStore.sendMessage(
                                    listing = saleListing,
                                    sender = user,
                                    recipient = counterpart,
                                    body = outcome.threadMessage,
                                    isSystem = true
                                )

                                outcome.contractPacket?.let { packet ->
                                conversationStore.sendContractPacket(
                                    listing = saleListing,
                                    offerId = outcome.offer.id,
                                    buyer = counterpart,
                                    seller = user,
                                    packet = packet,
                                    triggeredBy = user
                                    )
                                }

                                saleStore.refreshFromBackend()
                                noticeMessage = outcome.noticeMessage
                            }.onFailure { error ->
                                noticeMessage = error.message ?: "Could not send the seller response right now."
                            }
                            isSubmittingOffer = false
                        }
                    }
                )
            }

            item {
                LegalCoordinationCard(
                    user = user,
                    counterpart = counterpart,
                    offer = saleOffer,
                    mySelection = mySelection,
                    counterpartSelection = counterpartSelection,
                    invites = saleOffer.invites,
                    isLoading = isLoadingLegalResults,
                    searchError = legalSearchError,
                    onSearch = { launchLegalSearch() },
                    onShareInvite = { invite -> launchShareInvite(invite) },
                    onRegenerateInvite = { invite -> launchManageInvite(invite, SaleInviteManagementAction.REGENERATE) },
                    onRevokeInvite = { invite -> launchManageInvite(invite, SaleInviteManagementAction.REVOKE) },
                    onOpenSupport = { openLink(context, MarketplaceLinks.SUPPORT) }
                )
            }

            if (legalResults.isNotEmpty()) {
                items(legalResults, key = { professional -> professional.id }) { professional ->
                    LegalProfessionalCard(
                        professional = professional,
                        onSelect = { selectLegalProfessional(professional) },
                        onOpenWebsite = { url ->
                            openLink(context, url)
                        },
                        onOpenMaps = { url ->
                            openLink(context, url)
                        }
                    )
                }
            }

            saleOffer.contractPacket?.let { packet ->
                item {
                    ContractPacketCard(
                        packet = packet,
                        offer = saleOffer,
                        user = user,
                        isSubmitting = isSubmittingOffer,
                        onSign = { launchContractSigning() }
                    )
                }
            }

            if (saleOffer.documents.isNotEmpty()) {
                item {
                    SharedDocumentsCard(
                        documents = saleOffer.documents,
                        onShareDocument = { document ->
                            val buyer = if (user.role == UserRole.BUYER) user else counterpart
                            val seller = if (user.role == UserRole.SELLER) user else counterpart
                            runCatching {
                                val file = SaleDocumentRenderer.render(
                                    context = context,
                                    document = document,
                                    listing = saleListing,
                                    offer = saleOffer,
                                    buyer = buyer,
                                    seller = seller
                                )
                                shareSaleDocument(context, file, document.kind.title)
                            }.onSuccess {
                                noticeMessage = "${document.kind.title} is ready to share."
                            }.onFailure { error ->
                                noticeMessage = error.message ?: "Could not prepare the PDF right now."
                            }
                        }
                    )
                }
            }

            item {
                SecureMessagesCard(
                    conversation = conversation,
                    saleOffer = saleOffer,
                    currentUser = user,
                    counterpart = counterpart,
                    taskSnapshotStore = taskSnapshotStore,
                    taskSnapshotViewerId = taskSnapshotViewerId,
                    messageDraft = messageDraft,
                    onMessageDraftChange = { messageDraft = it },
                    onSend = {
                        coroutineScope.launch {
                            conversationStore.sendMessage(
                                listing = saleListing,
                                sender = user,
                                recipient = counterpart,
                                body = messageDraft
                            )
                            messageDraft = ""
                        }
                    },
                    onOpenMessageTask = { message ->
                        message.saleTaskTarget?.let(::openSaleTaskFromMessage)
                    }
                )
            }

            item {
                SaleUpdatesCard(
                    offer = saleOffer,
                    currentViewerId = taskSnapshotViewerId,
                    taskSnapshotStore = taskSnapshotStore
                )
            }

            item {
                LinksCard(
                    onOpenWebsite = { openLink(context, MarketplaceLinks.WEBSITE) },
                    onOpenPrivacy = { openLink(context, MarketplaceLinks.PRIVACY) },
                    onOpenTerms = { openLink(context, MarketplaceLinks.TERMS) },
                    onOpenSupport = { openLink(context, MarketplaceLinks.SUPPORT) }
                )
            }

            item {
                AccountCard(
                    email = account?.redactedEmail ?: "Preview account",
                    storageModeSummary = store.storageModeSummary,
                    backendEndpoint = store.backendEndpointSummary,
                    onOpenSupport = { openLink(context, MarketplaceLinks.SUPPORT) },
                    onSignOut = { store.signOut() },
                    onSwitchDemoAccount = { demoAccount ->
                        coroutineScope.launch {
                            runCatching {
                                store.signIn(demoAccount.email, demoAccount.password)
                                marketplaceStore.refreshForUser(store.currentUser.id)
                                saleStore.refreshFromBackend()
                                conversationStore.activateSession(
                                    user = store.currentUser,
                                    counterpart = saleStore.counterpartFor(store.currentUser),
                                    listing = saleStore.listing
                                )
                            }.onSuccess {
                                filters = filters.copy(
                                    suburb = store.currentUser.suburb.substringBefore(",").trim()
                                )
                                noticeMessage = "Signed in as ${demoAccount.accountName}."
                            }.onFailure { error ->
                                noticeMessage = error.message ?: "Could not switch demo accounts right now."
                            }
                        }
                    }
                )
            }
        }

        when (val reminderTask = activeReminderTask) {
            ReminderTaskDestination.LegalSearch -> ReminderLegalSearchDialog(
                listing = saleListing,
                actingRole = user.role,
                currentSelection = mySelection,
                results = legalResults,
                isLoading = isLoadingLegalResults,
                errorMessage = legalSearchError,
                onRefresh = { launchLegalSearch() },
                onSelect = { professional ->
                    selectLegalProfessional(professional) {
                        activeReminderTask = null
                    }
                },
                onDismiss = { activeReminderTask = null }
            )
            is ReminderTaskDestination.InviteManagement -> {
                val invite = saleOffer.latestInviteFor(reminderTask.role)
                if (invite != null) {
                    ReminderInviteManagementDialog(
                        invite = invite,
                        preferredAction = reminderTask.preferredAction,
                        onShare = {
                            activeReminderTask = null
                            launchShareInvite(invite)
                        },
                        onRegenerate = {
                            activeReminderTask = null
                            launchManageInvite(invite, SaleInviteManagementAction.REGENERATE)
                        },
                        onRevoke = {
                            activeReminderTask = null
                            launchManageInvite(invite, SaleInviteManagementAction.REVOKE)
                        },
                        onDismiss = { activeReminderTask = null }
                    )
                }
            }
            ReminderTaskDestination.ContractSigning -> {
                val packet = saleOffer.contractPacket
                if (packet != null) {
                    ReminderContractSigningDialog(
                        offer = saleOffer,
                        packet = packet,
                        user = user,
                        isSubmitting = isSubmittingOffer,
                        onSign = {
                            activeReminderTask = null
                            launchContractSigning()
                        },
                        onOpenMessages = {
                            activeReminderTask = null
                        },
                        onDismiss = { activeReminderTask = null }
                    )
                }
            }
            null -> Unit
        }
    }
}

@Composable
private fun GradientHeroCard(title: String, body: String) {
    Card(colors = CardDefaults.cardColors(containerColor = Color.Transparent)) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF0A2433),
                            Color(0xFF0B6B7A),
                            Color(0xFFF0B429)
                        )
                    )
                )
                .padding(22.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = body,
                    style = MaterialTheme.typography.titleMedium,
                    color = Color.White
                )
            }
        }
    }
}

@Composable
private fun SearchFiltersCard(
    filters: MarketplaceSearchFilters,
    savedSearchTitle: String,
    onFiltersChange: (MarketplaceSearchFilters) -> Unit,
    onSavedSearchTitleChange: (String) -> Unit,
    onSaveSearch: () -> Unit
) {
    SummaryCard(
        title = "Search private listings",
        body = "Filter by suburb, bedrooms, price, and property type, then save the search for later."
    ) {
        OutlinedTextField(
            value = filters.query,
            onValueChange = { onFiltersChange(filters.copy(query = it)) },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Keyword or address") }
        )
        OutlinedTextField(
            value = filters.suburb,
            onValueChange = { onFiltersChange(filters.copy(suburb = it)) },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Suburb") }
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedTextField(
                value = filters.minimumBedroomsText,
                onValueChange = { value ->
                    onFiltersChange(filters.copy(minimumBedroomsText = value.filter(Char::isDigit)))
                },
                modifier = Modifier.weight(1f),
                label = { Text("Min beds") }
            )
            OutlinedTextField(
                value = filters.maximumPriceText,
                onValueChange = { value ->
                    onFiltersChange(filters.copy(maximumPriceText = value.filter(Char::isDigit)))
                },
                modifier = Modifier.weight(1f),
                label = { Text("Max price") }
            )
        }
        MarketplacePropertyType.entries.toList().chunked(3).forEach { rowTypes ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                rowTypes.forEach { propertyType ->
                    FilterChip(
                        selected = propertyType in filters.propertyTypes,
                        onClick = {
                            val nextTypes = if (propertyType in filters.propertyTypes) {
                                filters.propertyTypes - propertyType
                            } else {
                                filters.propertyTypes + propertyType
                            }
                            onFiltersChange(filters.copy(propertyTypes = nextTypes))
                        },
                        label = { Text(propertyType.title) }
                    )
                }
            }
        }
        OutlinedTextField(
            value = savedSearchTitle,
            onValueChange = onSavedSearchTitleChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Saved search title") }
        )
        Button(
            onClick = onSaveSearch,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Save Search")
        }
    }
}

@Composable
private fun MarketplaceListingCard(
    listing: MarketplaceListing,
    isFavorite: Boolean,
    onToggleFavorite: () -> Unit
) {
    SummaryCard(
        title = listing.title,
        body = listing.headline
    ) {
        Text(text = listing.address.fullLine, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = listing.factLine, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            text = formatAud(listing.askingPrice),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = "${listing.propertyType.title} • ${listing.status.title}",
            color = Color(0xFF0B6B7A),
            fontWeight = FontWeight.SemiBold
        )
        Text(text = listing.summary, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (listing.features.isNotEmpty()) {
            Text(
                text = listing.features.take(4).joinToString(" • "),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Button(
            onClick = onToggleFavorite,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (isFavorite) "Remove Saved Home" else "Save Home")
        }
    }
}

@Composable
private fun SavedSearchCard(
    search: MarketplaceSavedSearch,
    onApply: () -> Unit,
    onToggleAlerts: () -> Unit
) {
    SummaryCard(
        title = search.title,
        body = buildString {
            append(search.suburb.ifBlank { "Any suburb" })
            append(" • ")
            append(if (search.minimumBedrooms > 0) "${search.minimumBedrooms}+ bedrooms" else "Any bedrooms")
            if (search.maximumPrice > 0) {
                append(" • Up to ${formatAud(search.maximumPrice)}")
            }
        }
    ) {
        if (search.propertyTypes.isNotEmpty()) {
            Text(
                text = search.propertyTypes.joinToString(" • ") { type -> type.title },
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(onClick = onApply, modifier = Modifier.weight(1f)) {
                Text("Apply Search")
            }
            OutlinedButton(onClick = onToggleAlerts, modifier = Modifier.weight(1f)) {
                Text(if (search.alertsEnabled) "Alerts On" else "Alerts Off")
            }
        }
    }
}

@Composable
private fun FocusedChecklistActionCard(
    prompt: FocusedChecklistActionPrompt,
    snoozedUntilMillis: Long?,
    activityEntries: List<SaleReminderScheduler.ReminderActivityEntry>,
    onRunAction: () -> Unit,
    onSnooze: () -> Unit
) {
    SummaryCard(
        title = "Reminder shortcut",
        body = prompt.title
    ) {
        Text(
            text = prompt.message,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        snoozedUntilMillis?.let { timestamp ->
            Text(
                text = "Snoozed until ${formatTimestamp(timestamp)}",
                color = Color(0xFF0B6B7A),
                fontWeight = FontWeight.SemiBold
            )
        }
        Button(onClick = onRunAction, modifier = Modifier.fillMaxWidth()) {
            Text(prompt.buttonLabel)
        }
        OutlinedButton(onClick = onSnooze, modifier = Modifier.fillMaxWidth()) {
            Text("Snooze 24 Hours")
        }
        if (activityEntries.isNotEmpty()) {
            Text(
                text = "Reminder activity",
                fontWeight = FontWeight.SemiBold
            )
            activityEntries.take(3).forEach { entry ->
                Text(
                    text = "${entry.title} • ${formatTimestamp(entry.createdAtMillis)}",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun ReminderTaskDialogFrame(
    title: String,
    body: String,
    onDismiss: () -> Unit,
    content: @Composable ColumnScope.() -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Surface(
            shape = MaterialTheme.shapes.extraLarge,
            color = Color.White,
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
        ) {
            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = body,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                content()
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) {
                        Text("Close")
                    }
                }
            }
        }
    }
}

@Composable
private fun ReminderLegalSearchDialog(
    listing: SaleListing,
    actingRole: UserRole,
    currentSelection: LegalSelection?,
    results: List<LegalProfessional>,
    isLoading: Boolean,
    errorMessage: String?,
    onRefresh: () -> Unit,
    onSelect: (LegalProfessional) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current

    ReminderTaskDialogFrame(
        title = "Choose legal rep",
        body = if (actingRole == UserRole.BUYER) {
            "Pick the buyer-side conveyancer, solicitor, or property lawyer for ${listing.address.suburb}."
        } else {
            "Pick the seller-side conveyancer, solicitor, or property lawyer for ${listing.address.suburb}."
        },
        onDismiss = onDismiss
    ) {
        SelectionCard(
            title = if (actingRole == UserRole.BUYER) {
                "Current buyer-side selection"
            } else {
                "Current seller-side selection"
            },
            selection = currentSelection
        )
        Button(onClick = onRefresh, modifier = Modifier.fillMaxWidth()) {
            Text(if (results.isEmpty()) "Search Nearby Legal Reps" else "Refresh Legal Search")
        }
        if (isLoading) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                CircularProgressIndicator()
                Text(
                    text = "Searching local legal professionals…",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        errorMessage?.let { message ->
            NoticeCard(message = message)
        }
        if (!isLoading && results.isEmpty() && errorMessage == null) {
            NoticeCard(message = "No nearby legal professionals were found for this suburb yet.")
        }
        results.forEach { professional ->
            LegalProfessionalCard(
                professional = professional,
                onSelect = { onSelect(professional) },
                onOpenWebsite = { url -> openLink(context, url) },
                onOpenMaps = { url -> openLink(context, url) }
            )
        }
    }
}

@Composable
private fun ReminderInviteManagementDialog(
    invite: SaleWorkspaceInvite,
    preferredAction: FocusedChecklistActionType,
    onShare: () -> Unit,
    onRegenerate: () -> Unit,
    onRevoke: () -> Unit,
    onDismiss: () -> Unit
) {
    ReminderTaskDialogFrame(
        title = "Invite access",
        body = "Manage the legal workspace invite for ${invite.professionalName} without leaving the reminder flow.",
        onDismiss = onDismiss
    ) {
        InviteCard(
            invite = invite,
            onShareInvite = onShare,
            onRegenerateInvite = onRegenerate,
            onRevokeInvite = onRevoke
        )
        Button(
            onClick = if (preferredAction == FocusedChecklistActionType.REGENERATE_INVITE) onRegenerate else onShare,
            modifier = Modifier.fillMaxWidth(),
            enabled = preferredAction != FocusedChecklistActionType.SHARE_INVITE || !invite.isUnavailable
        ) {
            Text(
                when (preferredAction) {
                    FocusedChecklistActionType.REGENERATE_INVITE -> "Regenerate Invite"
                    else -> if (invite.hasBeenShared) "Resend Invite" else "Share Invite"
                }
            )
        }
    }
}

@Composable
private fun ReminderContractSigningDialog(
    offer: SaleOffer,
    packet: ContractPacket,
    user: MarketplaceUserProfile,
    isSubmitting: Boolean,
    onSign: () -> Unit,
    onOpenMessages: () -> Unit,
    onDismiss: () -> Unit
) {
    ReminderTaskDialogFrame(
        title = "Contract signing",
        body = "Review the current signature status and record your sign-off from the reminder workflow.",
        onDismiss = onDismiss
    ) {
        ContractPacketCard(
            packet = packet,
            offer = offer,
            user = user,
            isSubmitting = isSubmitting,
            onSign = onSign
        )
        OutlinedButton(
            onClick = onOpenMessages,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Back to Sale Workspace")
        }
    }
}

@Composable
private fun SaleWorkspaceCard(
    user: MarketplaceUserProfile,
    listing: SaleListing,
    offer: SaleOffer,
    focusedChecklistItemId: String?,
    offerAmountDraft: String,
    offerConditionsDraft: String,
    isSubmittingOffer: Boolean,
    onOfferAmountChange: (String) -> Unit,
    onOfferConditionsChange: (String) -> Unit,
    onSubmitOffer: () -> Unit,
    onSellerAction: (SellerOfferAction) -> Unit
) {
    SummaryCard(
        title = "Live sale workspace",
        body = if (user.role == UserRole.SELLER) {
            "The seller workspace keeps the live offer, legal handoff, and secure conversation together."
        } else {
            "The buyer workspace keeps the current offer, legal handoff, and secure conversation together."
        }
    ) {
        Text(text = listing.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(text = listing.address.fullLine, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = listing.factLine, color = MaterialTheme.colorScheme.onSurfaceVariant)
        MetricRow(label = "Ask", value = formatAud(listing.askingPrice))
        MetricRow(label = "Offer", value = formatAud(offer.amount))
        MetricRow(label = "Status", value = offer.status.title)
        MetricRow(label = "Sent", value = formatTimestamp(offer.createdAt))
        MetricRow(label = "Conditions", value = offer.conditions)
        Text(
            text = "Settlement checklist",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold
        )
        Text(
            text = "Everyone in the deal sees the same milestones from legal rep selection through to settlement.",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        SettlementChecklistContent(
            items = offer.settlementChecklist,
            focusedChecklistItemId = focusedChecklistItemId
        )
        if (user.role == UserRole.BUYER) {
            if (offer.status == SaleOfferStatus.ACCEPTED) {
                Text(
                    text = "The seller has accepted these terms. Next step: finish legal coordination and contract exchange.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                OutlinedTextField(
                    value = offerAmountDraft,
                    onValueChange = onOfferAmountChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text(if (offer.status == SaleOfferStatus.COUNTERED) "Counter amount" else "Offer amount") }
                )
                OutlinedTextField(
                    value = offerConditionsDraft,
                    onValueChange = onOfferConditionsChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = {
                        Text(
                            if (offer.status == SaleOfferStatus.CHANGES_REQUESTED) {
                                "Updated conditions"
                            } else {
                                "Offer conditions"
                            }
                        )
                    }
                )
                Button(
                    onClick = onSubmitOffer,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isSubmittingOffer &&
                        offerAmountDraft.filter(Char::isDigit).toIntOrNull()?.let { amount ->
                            amount > 0 && (
                                amount != offer.amount ||
                                    offerConditionsDraft.trim() != offer.conditions.trim() ||
                                    offer.status != SaleOfferStatus.UNDER_OFFER
                                )
                        } == true &&
                        offerConditionsDraft.isNotBlank()
                ) {
                    Text(
                        when {
                            isSubmittingOffer -> "Sending Offer..."
                            offer.status == SaleOfferStatus.COUNTERED -> "Respond to Counteroffer"
                            offer.status == SaleOfferStatus.CHANGES_REQUESTED -> "Send Updated Terms"
                            else -> "Update Offer"
                        }
                    )
                }
            }
        } else {
            OutlinedTextField(
                value = offerAmountDraft,
                onValueChange = onOfferAmountChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Seller response amount") }
            )
            OutlinedTextField(
                value = offerConditionsDraft,
                onValueChange = onOfferConditionsChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Seller terms or notes") }
            )
            Text(
                text = "Accept the offer as-is, request changes, or send a counteroffer back to the buyer without leaving the sale workspace.",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Button(
                onClick = { onSellerAction(SellerOfferAction.ACCEPT) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isSubmittingOffer && offer.status != SaleOfferStatus.ACCEPTED
            ) {
                Text(if (isSubmittingOffer) "Processing..." else "Accept Offer")
            }
            OutlinedButton(
                onClick = { onSellerAction(SellerOfferAction.REQUEST_CHANGES) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isSubmittingOffer && offerConditionsDraft.isNotBlank()
            ) {
                Text("Request Changes")
            }
            OutlinedButton(
                onClick = { onSellerAction(SellerOfferAction.COUNTER) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isSubmittingOffer &&
                    offerAmountDraft.filter(Char::isDigit).toIntOrNull()?.let { amount -> amount > 0 } == true &&
                    offerConditionsDraft.isNotBlank()
            ) {
                Text("Send Counteroffer")
            }
        }
    }
}

private fun deriveFocusedChecklistActionPrompt(
    user: MarketplaceUserProfile,
    offer: SaleOffer,
    focusedChecklistItemId: String?
): FocusedChecklistActionPrompt? {
    val item = offer.settlementChecklist.firstOrNull { it.id == focusedChecklistItemId } ?: return null
    val message = item.nextActionSummary ?: item.reminderSummary ?: item.detail
    val currentInviteRole = when (user.role) {
        UserRole.BUYER -> LegalInviteRole.BUYER_REPRESENTATIVE
        UserRole.SELLER -> LegalInviteRole.SELLER_REPRESENTATIVE
    }

    return when (item.id) {
        "buyer-representative" -> {
            if (user.role == UserRole.BUYER && offer.buyerLegalSelection == null) {
                FocusedChecklistActionPrompt(
                    title = item.title,
                    message = message,
                    buttonLabel = "Search legal reps",
                    action = FocusedChecklistActionType.SEARCH_LEGAL_REPS
                )
            } else {
                null
            }
        }
        "seller-representative" -> {
            if (user.role == UserRole.SELLER && offer.sellerLegalSelection == null) {
                FocusedChecklistActionPrompt(
                    title = item.title,
                    message = message,
                    buttonLabel = "Search legal reps",
                    action = FocusedChecklistActionType.SEARCH_LEGAL_REPS
                )
            } else {
                null
            }
        }
        "contract-packet" -> {
            val currentSelectionMissing = when (user.role) {
                UserRole.BUYER -> offer.buyerLegalSelection == null
                UserRole.SELLER -> offer.sellerLegalSelection == null
            }

            if (currentSelectionMissing) {
                FocusedChecklistActionPrompt(
                    title = item.title,
                    message = message,
                    buttonLabel = "Search legal reps",
                    action = FocusedChecklistActionType.SEARCH_LEGAL_REPS
                )
            } else {
                null
            }
        }
        "workspace-invites", "workspace-active" -> {
            val invite = offer.latestInviteFor(currentInviteRole) ?: return null
            if (invite.isUnavailable) {
                FocusedChecklistActionPrompt(
                    title = item.title,
                    message = message,
                    buttonLabel = "Regenerate invite",
                    action = FocusedChecklistActionType.REGENERATE_INVITE,
                    inviteRole = currentInviteRole
                )
            } else {
                FocusedChecklistActionPrompt(
                    title = item.title,
                    message = message,
                    buttonLabel = if (invite.hasBeenShared) "Resend invite" else "Share invite",
                    action = FocusedChecklistActionType.SHARE_INVITE,
                    inviteRole = currentInviteRole
                )
            }
        }
        "contract-signatures" -> {
            if (offer.status == SaleOfferStatus.ACCEPTED &&
                offer.contractPacket?.signedAtFor(user) == null &&
                offer.contractPacket?.isFullySigned == false
            ) {
                FocusedChecklistActionPrompt(
                    title = item.title,
                    message = message,
                    buttonLabel = "Sign contract packet",
                    action = FocusedChecklistActionType.SIGN_CONTRACT
                )
            } else {
                null
            }
        }
        else -> null
    }
}

private fun SaleOffer.latestInviteFor(role: LegalInviteRole): SaleWorkspaceInvite? {
    return invites
        .filter { it.role == role }
        .maxByOrNull { it.createdAt }
}

@Composable
private fun LegalCoordinationCard(
    user: MarketplaceUserProfile,
    counterpart: MarketplaceUserProfile,
    offer: SaleOffer,
    mySelection: LegalSelection?,
    counterpartSelection: LegalSelection?,
    invites: List<SaleWorkspaceInvite>,
    isLoading: Boolean,
    searchError: String?,
    onSearch: () -> Unit,
    onShareInvite: (SaleWorkspaceInvite) -> Unit,
    onRegenerateInvite: (SaleWorkspaceInvite) -> Unit,
    onRevokeInvite: (SaleWorkspaceInvite) -> Unit,
    onOpenSupport: () -> Unit
) {
    SummaryCard(
        title = "Legal coordination",
        body = "Search nearby conveyancers, solicitors, and property lawyers, then let each side choose who will handle the transaction."
    ) {
        Text(text = "Settlement checklist", fontWeight = FontWeight.SemiBold)
        Text(
            text = "Track the shared legal, contract, and settlement milestones without leaving the sale workspace.",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        SettlementChecklistContent(items = offer.settlementChecklist)
        SelectionCard(
            title = if (user.role == UserRole.BUYER) {
                "Your buyer-side representative"
            } else {
                "Your seller-side representative"
            },
            selection = mySelection
        )
        SelectionCard(
            title = "${counterpart.name}'s representative",
            selection = counterpartSelection
        )
        if (invites.isNotEmpty()) {
            Text(text = "Legal representative access", fontWeight = FontWeight.SemiBold)
            Text(
                text = "Share the workspace invite with the chosen conveyancer or solicitor so they can work from the current contract, rates, ID, and settlement documents.",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            invites
                .sortedWith(compareBy<SaleWorkspaceInvite> { it.isUnavailable }.thenByDescending { it.createdAt })
                .forEach { invite ->
                    InviteCard(
                        invite = invite,
                        onShareInvite = { onShareInvite(invite) },
                        onRegenerateInvite = { onRegenerateInvite(invite) },
                        onRevokeInvite = { onRevokeInvite(invite) }
                    )
                }
        }
        if (isLoading) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                CircularProgressIndicator()
                Text(
                    text = "Loading nearby legal professionals…",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        searchError?.let { error ->
            NoticeCard(message = error)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(onClick = onSearch, modifier = Modifier.weight(1f)) {
                Text(if (mySelection == null) "Search Legal Reps" else "Refresh Legal Search")
            }
            OutlinedButton(onClick = onOpenSupport, modifier = Modifier.weight(1f)) {
                Text("Open Support")
            }
        }
    }
}

@Composable
private fun InviteCard(
    invite: SaleWorkspaceInvite,
    onShareInvite: () -> Unit,
    onRegenerateInvite: () -> Unit,
    onRevokeInvite: () -> Unit
) {
    Surface(
        color = Color(0xFFF4FAFD),
        shape = MaterialTheme.shapes.large,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(text = invite.role.title, fontWeight = FontWeight.SemiBold)
            Text(text = invite.professionalName, fontWeight = FontWeight.Bold)
            Text(
                text = invite.professionalSpecialty,
                color = Color(0xFF0B6B7A),
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = "Invite code ${invite.shareCode}",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "Created ${formatTimestamp(invite.createdAt)} by ${invite.generatedByName}",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall
            )
            if (invite.isRevoked) {
                Text(
                    text = "Revoked ${invite.revokedAt?.let(::formatTimestamp).orEmpty()}",
                    color = MaterialTheme.colorScheme.error,
                    fontWeight = FontWeight.SemiBold
                )
            } else if (invite.isExpired) {
                Text(
                    text = "Expired ${formatTimestamp(invite.expiresAt)}",
                    color = MaterialTheme.colorScheme.error,
                    fontWeight = FontWeight.SemiBold
                )
            } else {
                Text(
                    text = "Valid until ${formatTimestamp(invite.expiresAt)}",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontWeight = FontWeight.SemiBold
                )
            }
            invite.acknowledgedAt?.let {
                Text(
                    text = "Acknowledged ${formatTimestamp(it)}",
                    color = Color(0xFF0B6B7A),
                    fontWeight = FontWeight.SemiBold
                )
            }
            invite.lastSharedAt?.let {
                Text(
                    text = "Last sent ${formatTimestamp(it)} • ${invite.shareCount}x shared",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontWeight = FontWeight.SemiBold
                )
            } ?: Text(
                text = "Not yet sent from the sale workspace",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = FontWeight.SemiBold
            )
            if (invite.activatedAt != null) {
                Text(
                    text = "Opened ${formatTimestamp(invite.activatedAt)}",
                    color = Color(0xFF0B6B7A),
                    fontWeight = FontWeight.SemiBold
                )
            } else if (invite.needsFollowUp) {
                Text(
                    text = "Follow up recommended. It has not been opened within 48 hours.",
                    color = Color(0xFFB25B00),
                    fontWeight = FontWeight.SemiBold
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = onShareInvite,
                    enabled = !invite.isUnavailable
                ) {
                    Text("Resend Invite")
                }
                OutlinedButton(onClick = onRegenerateInvite) {
                    Text("Regenerate")
                }
                OutlinedButton(
                    onClick = onRevokeInvite,
                    enabled = !invite.isRevoked
                ) {
                    Text("Revoke")
                }
            }
        }
    }
}

@Composable
private fun SelectionCard(title: String, selection: LegalSelection?) {
    Surface(
        color = Color(0xFFF4FAFD),
        shape = MaterialTheme.shapes.large,
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(text = title, fontWeight = FontWeight.SemiBold)
            if (selection == null) {
                Text(text = "Not selected yet", fontWeight = FontWeight.Bold)
                Text(
                    text = "This side still needs to choose a conveyancer, solicitor, or property lawyer.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                Text(text = selection.professional.name, fontWeight = FontWeight.Bold)
                Text(
                    text = selection.professional.primarySpecialty,
                    color = Color(0xFF0B6B7A),
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = selection.professional.address,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "Chosen ${formatTimestamp(selection.selectedAt)}",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

@Composable
private fun LegalProfessionalCard(
    professional: LegalProfessional,
    onSelect: () -> Unit,
    onOpenWebsite: (String) -> Unit,
    onOpenMaps: (String) -> Unit
) {
    SummaryCard(
        title = professional.name,
        body = professional.searchSummary
    ) {
        Text(
            text = professional.primarySpecialty,
            color = Color(0xFF0B6B7A),
            fontWeight = FontWeight.SemiBold
        )
        Text(text = professional.address, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = professional.sourceLine, color = MaterialTheme.colorScheme.onSurfaceVariant)
        professional.rating?.let { rating ->
            val reviews = professional.reviewCount?.let { count -> " • $count reviews" }.orEmpty()
            Text(text = "${"%.1f".format(rating)}$reviews", fontWeight = FontWeight.SemiBold)
        }
        professional.phoneNumber?.let { phone ->
            Text(text = phone, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onSelect, modifier = Modifier.weight(1f)) {
                Text("Choose for Sale")
            }
            professional.websiteUrl?.let { url ->
                OutlinedButton(
                    onClick = { onOpenWebsite(url) },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("Website")
                }
            }
            professional.mapsUrl?.let { url ->
                OutlinedButton(
                    onClick = { onOpenMaps(url) },
                    modifier = Modifier.weight(1f)
                ) {
                    Text("Maps")
                }
            }
        }
    }
}

@Composable
private fun ContractPacketCard(
    packet: ContractPacket,
    offer: SaleOffer,
    user: MarketplaceUserProfile,
    isSubmitting: Boolean,
    onSign: () -> Unit
) {
    SummaryCard(
        title = if (packet.isFullySigned) "Sale complete" else "Contract packet sent",
        body = if (packet.isFullySigned) {
            "Both buyer and seller have signed the contract packet. The listing is now marked sold."
        } else {
            packet.summary
        }
    ) {
        MetricRow(label = "Buyer legal rep", value = packet.buyerRepresentative.name)
        MetricRow(label = "Seller legal rep", value = packet.sellerRepresentative.name)
        MetricRow(label = "Issued", value = formatTimestamp(packet.generatedAt))
        MetricRow(
            label = "Buyer sign-off",
            value = packet.buyerSignedAt?.let(::formatTimestamp) ?: "Waiting"
        )
        MetricRow(
            label = "Seller sign-off",
            value = packet.sellerSignedAt?.let(::formatTimestamp) ?: "Waiting"
        )

        val signedAtForCurrentUser = packet.signedAtFor(user)
        when {
            packet.isFullySigned -> {
                Text(
                    text = "The contract has been signed by both sides and the private sale is complete.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            offer.status != SaleOfferStatus.ACCEPTED -> {
                Text(
                    text = "The seller needs to accept the current terms before signing can begin.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            signedAtForCurrentUser != null -> {
                Text(
                    text = "Your sign-off is recorded. Waiting for the other side to sign.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            else -> {
                Button(
                    onClick = onSign,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isSubmitting
                ) {
                    Text(if (isSubmitting) "Recording Signature..." else "Sign Contract Packet")
                }
            }
        }
    }
}

@Composable
private fun SharedDocumentsCard(
    documents: List<SaleDocument>,
    onShareDocument: (SaleDocument) -> Unit
) {
    SummaryCard(
        title = "Shared sale documents",
        body = "Contract PDFs stay attached to the sale so buyer and seller can work from the same latest packet and signed copy."
    ) {
        documents
            .sortedByDescending { it.createdAt }
            .forEach { document ->
                Surface(
                    color = Color(0xFFF9FBFC),
                    shape = MaterialTheme.shapes.large,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(text = document.kind.title, fontWeight = FontWeight.SemiBold)
                        Text(text = document.summary, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            text = "${document.fileName} • Added ${formatTimestamp(document.createdAt)} by ${document.uploadedByName}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        OutlinedButton(onClick = { onShareDocument(document) }) {
                            Text("Share PDF")
                        }
                    }
                }
            }
    }
}

@Composable
private fun SecureMessagesCard(
    conversation: ConversationThread?,
    saleOffer: SaleOffer,
    currentUser: MarketplaceUserProfile,
    counterpart: MarketplaceUserProfile,
    taskSnapshotStore: ConversationTaskSnapshotSyncStore,
    taskSnapshotViewerId: String?,
    messageDraft: String,
    onMessageDraftChange: (String) -> Unit,
    onSend: () -> Unit,
    onOpenMessageTask: (ConversationMessage) -> Unit
) {
    val liveSnapshotNow by produceState(
        initialValue = System.currentTimeMillis(),
        key1 = conversation?.id,
        key2 = saleOffer.id
    ) {
        while (true) {
            delay(60_000L)
            value = System.currentTimeMillis()
        }
    }

    SummaryCard(
        title = "Secure thread",
        body = "Buyer and seller messages sync through the local backend and stay stored in the encrypted Android message vault on this device."
    ) {
        Text(text = "Talking with ${counterpart.name}", fontWeight = FontWeight.SemiBold)
        Text(
            text = conversation?.encryptionLabel ?: "Preparing secure thread",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        val recentMessages = conversation?.messages?.takeLast(4).orEmpty()
        if (recentMessages.isEmpty()) {
            Text(
                text = "Open a sale conversation and send the first message.",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            recentMessages.forEach { message ->
                val taskTheme = conversationTaskTheme(message.saleTaskTarget)
                Surface(
                    color = if (message.isSystem && message.saleTaskTarget != null) {
                        taskTheme.background
                    } else if (message.senderId == currentUser.id) {
                        Color(0xFFE4F3F1)
                    } else {
                        Color(0xFFF6F8FA)
                    },
                    shape = MaterialTheme.shapes.large,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        if (message.isSystem && message.saleTaskTarget != null) {
                            ConversationTaskUpdate(
                                message = message,
                                saleOffer = saleOffer,
                                now = liveSnapshotNow,
                                taskSnapshotStore = taskSnapshotStore,
                                viewerId = taskSnapshotViewerId,
                                onOpenMessageTask = onOpenMessageTask
                            )
                        } else {
                            Text(
                                text = when {
                                    message.isSystem -> "System update"
                                    message.senderId == currentUser.id -> "You"
                                    else -> counterpart.name
                                },
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(text = message.body)
                            Text(
                                text = formatTimestamp(message.sentAt),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            if (message.saleTaskTarget != null) {
                                TextButton(
                                    onClick = { onOpenMessageTask(message) },
                                    contentPadding = PaddingValues(0.dp)
                                ) {
                                    Text(conversationSaleTaskButtonLabel(message.saleTaskTarget))
                                }
                            }
                        }
                    }
                }
            }
        }
        OutlinedTextField(
            value = messageDraft,
            onValueChange = onMessageDraftChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Message ${counterpart.name}") }
        )
        Button(
            onClick = onSend,
            modifier = Modifier.fillMaxWidth(),
            enabled = messageDraft.isNotBlank()
        ) {
            Text("Send Secure Message")
        }
    }
}

@Composable
private fun SaleUpdatesCard(
    offer: SaleOffer,
    currentViewerId: String?,
    taskSnapshotStore: ConversationTaskSnapshotSyncStore
) {
    SummaryCard(
        title = "Secure sale updates",
        body = "Key legal and contract milestones stay visible in the shared deal timeline."
    ) {
        offer.updates.take(6).forEach { update ->
            val checklistItemId = update.checklistItemId
            val liveSnapshot = checklistItemId?.let(offer::liveTaskSnapshot)
            Surface(
                color = Color(0xFFF9FBFC),
                shape = MaterialTheme.shapes.large,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    ReminderTimelineBadge(
                        update = update,
                        snapshot = liveSnapshot,
                        taskId = checklistItemId?.let(offer::taskSnapshotId),
                        audience = offer.taskSnapshotAudienceMembers,
                        taskSnapshotStore = taskSnapshotStore
                    )
                    Text(text = update.title, fontWeight = FontWeight.SemiBold)
                    Text(text = update.body, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (checklistItemId != null && liveSnapshot != null) {
                        SaleTaskAudienceStatusRow(
                            snapshot = liveSnapshot,
                            taskId = offer.taskSnapshotId(checklistItemId),
                            audience = offer.taskSnapshotAudienceMembers,
                            currentViewerId = currentViewerId,
                            taskSnapshotStore = taskSnapshotStore,
                            markAsSeenOnAppear = true
                        )
                    }
                    Text(
                        text = formatTimestamp(update.createdAt),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun ReminderTimelineBadge(
    update: SaleUpdateMessage,
    snapshot: SaleTaskLiveSnapshot? = null,
    taskId: String? = null,
    audience: List<SaleTaskSnapshotAudienceMember> = emptyList(),
    taskSnapshotStore: ConversationTaskSnapshotSyncStore? = null
) {
    val containerColor = if (update.kind == SaleUpdateKind.REMINDER) {
        Color(0xFFFCE8D8)
    } else {
        Color(0xFFDDEFF2)
    }
    val contentColor = if (update.kind == SaleUpdateKind.REMINDER) {
        Color(0xFFB86B12)
    } else {
        Color(0xFF0F6B78)
    }

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        Surface(
            color = containerColor,
            shape = MaterialTheme.shapes.extraLarge
        ) {
            Text(
                text = update.kind.label,
                color = contentColor,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp)
            )
        }
        if (snapshot != null && taskSnapshotStore != null && audience.isNotEmpty()) {
            SaleTaskAudienceCompactBadge(
                snapshot = snapshot,
                taskId = taskId,
                audience = audience,
                taskSnapshotStore = taskSnapshotStore
            )
        }
    }
}

@Composable
private fun LinksCard(
    onOpenWebsite: () -> Unit,
    onOpenPrivacy: () -> Unit,
    onOpenTerms: () -> Unit,
    onOpenSupport: () -> Unit
) {
    SummaryCard(
        title = "Launch links",
        body = "Your live website, privacy policy, terms, and support pages stay attached to the Android flow too."
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = onOpenWebsite) { Text("Website") }
            TextButton(onClick = onOpenPrivacy) { Text("Privacy") }
            TextButton(onClick = onOpenTerms) { Text("Terms") }
            TextButton(onClick = onOpenSupport) { Text("Support") }
        }
    }
}

@Composable
private fun AccountCard(
    email: String,
    storageModeSummary: String,
    backendEndpoint: String,
    onOpenSupport: () -> Unit,
    onSignOut: () -> Unit,
    onSwitchDemoAccount: (DemoAccountShortcut) -> Unit
) {
    SummaryCard(
        title = "Signed-in account",
        body = email
    ) {
        Text(
            text = storageModeSummary,
            fontWeight = FontWeight.SemiBold,
            color = Color(0xFF0B6B7A)
        )
        Text(
            text = backendEndpoint,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        demoAccountShortcuts.forEach { account ->
            OutlinedButton(
                onClick = { onSwitchDemoAccount(account) },
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(text = account.label, fontWeight = FontWeight.SemiBold)
                    Text(
                        text = account.accountName,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        Button(
            onClick = onOpenSupport,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Open Support")
        }
        OutlinedButton(
            onClick = onSignOut,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Sign Out")
        }
    }
}

@Composable
private fun NoticeCard(message: String) {
    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFE7F5F5))) {
        Text(
            text = message,
            modifier = Modifier.padding(18.dp),
            color = Color(0xFF084C54),
            style = MaterialTheme.typography.bodyMedium
        )
    }
}

@Composable
private fun SummaryCard(
    title: String,
    body: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = body,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            content()
        }
    }
}

@Composable
private fun MetricRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(text = label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = value, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun ConversationTaskUpdate(
    message: ConversationMessage,
    saleOffer: SaleOffer,
    now: Long,
    taskSnapshotStore: ConversationTaskSnapshotSyncStore,
    viewerId: String?,
    onOpenMessageTask: (ConversationMessage) -> Unit
) {
    val target = message.saleTaskTarget
    val theme = conversationTaskTheme(target)
    val status = conversationTaskStatus(message)
    val liveSnapshot = target?.let { saleOffer.liveTaskSnapshot(it.checklistItemId, now) }
    val taskSnapshotId = target?.let { saleOffer.taskSnapshotId(it.checklistItemId) }
    val shouldEmphasizeUrgentSnapshot = liveSnapshot != null &&
        taskSnapshotStore.shouldEmphasizeUrgentSnapshot(
            snapshot = liveSnapshot,
            messageId = message.id,
            viewerId = viewerId,
            taskId = taskSnapshotId
        )
    val hapticFeedback = LocalHapticFeedback.current

    val liveSnapshotKey = liveSnapshot?.let { "${it.tone.name}|${it.summary}" }

    LaunchedEffect(message.id, viewerId, liveSnapshotKey, shouldEmphasizeUrgentSnapshot) {
        if (shouldEmphasizeUrgentSnapshot) {
            val snapshot = liveSnapshot ?: return@LaunchedEffect
            taskSnapshotStore.markUrgentSnapshotSeen(
                snapshot = snapshot,
                messageId = message.id,
                viewerId = viewerId,
                taskId = taskSnapshotId
            )
            hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                color = theme.badgeBackground,
                shape = MaterialTheme.shapes.small
            ) {
                Text(
                    text = theme.stageLabel,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = theme.badgeText,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp)
                )
            }
            if (liveSnapshot != null) {
                SaleTaskAudienceCompactBadge(
                    snapshot = liveSnapshot,
                    messageId = message.id,
                    taskId = taskSnapshotId,
                    audience = saleOffer.taskSnapshotAudienceMembers,
                    taskSnapshotStore = taskSnapshotStore
                )
            }
            ConversationTaskStatusChip(status = status)
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                color = theme.accent.copy(alpha = 0.14f),
                shape = CircleShape
            ) {
                Icon(
                    imageVector = conversationSaleTaskIcon(target),
                    contentDescription = null,
                    tint = theme.accent,
                    modifier = Modifier.padding(8.dp).size(18.dp)
                )
            }

            Column(
                verticalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.weight(1f, fill = false)
            ) {
                Text(
                    text = conversationSaleTaskTitle(target),
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = status.label,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = status.tint
                )
                val liveAnimationStyle = conversationTaskLiveAnimationStyle(
                    snapshot = liveSnapshot,
                    emphasizeUrgentSnapshot = shouldEmphasizeUrgentSnapshot
                )
                AnimatedContent(
                    targetState = liveSnapshot,
                    label = "conversationTaskLiveSnapshot",
                    transitionSpec = {
                        (
                            fadeIn(animationSpec = tween(durationMillis = liveAnimationStyle.enterDurationMillis)) +
                                scaleIn(
                                    animationSpec = tween(durationMillis = liveAnimationStyle.enterDurationMillis),
                                    initialScale = liveAnimationStyle.enterScale
                                )
                            ).togetherWith(
                            fadeOut(animationSpec = tween(durationMillis = liveAnimationStyle.exitDurationMillis)) +
                                scaleOut(
                                    animationSpec = tween(durationMillis = liveAnimationStyle.exitDurationMillis),
                                    targetScale = liveAnimationStyle.exitScale
                                )
                        )
                    }
                ) { currentSnapshot ->
                    if (currentSnapshot != null) {
                        ConversationTaskLiveSnapshotChip(
                            snapshot = currentSnapshot,
                            emphasizeUrgentSnapshot = shouldEmphasizeUrgentSnapshot
                        )
                    }
                }
                if (liveSnapshot != null) {
                    SaleTaskAudienceStatusRow(
                        snapshot = liveSnapshot,
                        messageId = message.id,
                        taskId = taskSnapshotId,
                        audience = saleOffer.taskSnapshotAudienceMembers,
                        currentViewerId = viewerId,
                        taskSnapshotStore = taskSnapshotStore
                    )
                }
            }
        }
        conversationMessageDetailLines(message).forEach { line ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(
                    modifier = Modifier
                        .padding(top = 6.dp)
                        .size(6.dp)
                        .background(theme.accent.copy(alpha = 0.45f), shape = MaterialTheme.shapes.small)
                )
                Text(
                    text = line,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f, fill = false)
                )
            }
        }
        Text(
            text = formatTimestamp(message.sentAt),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        if (target != null) {
            TextButton(
                onClick = { onOpenMessageTask(message) },
                contentPadding = PaddingValues(0.dp)
            ) {
                Text(
                    text = conversationSaleTaskButtonLabel(target),
                    color = theme.accent
                )
            }
        }
    }
}

@Composable
private fun ConversationTaskStatusChip(status: ConversationTaskStatus) {
    Surface(
        color = status.background,
        shape = MaterialTheme.shapes.extraLarge
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = status.icon,
                contentDescription = null,
                tint = status.tint,
                modifier = Modifier.size(14.dp)
            )
            Text(
                text = status.label,
                color = status.tint,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun ConversationTaskLiveSnapshotChip(
    snapshot: SaleTaskLiveSnapshot,
    emphasizeUrgentSnapshot: Boolean
) {
    val style = conversationTaskLiveStyle(snapshot)
    val liveRegionMode = if (emphasizeUrgentSnapshot) {
        LiveRegionMode.Assertive
    } else {
        LiveRegionMode.Polite
    }

    Surface(
        modifier = Modifier.semantics {
            liveRegion = liveRegionMode
        },
        color = style.background,
        shape = MaterialTheme.shapes.medium
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = style.icon,
                contentDescription = null,
                tint = style.tint,
                modifier = Modifier.size(14.dp)
            )
            Text(
                text = snapshot.summary,
                color = style.tint,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

private data class ConversationTaskTheme(
    val accent: Color,
    val background: Color,
    val badgeBackground: Color,
    val badgeText: Color,
    val stageLabel: String
)

private data class ConversationTaskStatus(
    val label: String,
    val icon: ImageVector,
    val tint: Color,
    val background: Color
)

private data class ConversationTaskLiveStyle(
    val tint: Color,
    val background: Color,
    val icon: ImageVector
)

private data class ConversationTaskLiveAnimationStyle(
    val enterScale: Float,
    val exitScale: Float,
    val enterDurationMillis: Int,
    val exitDurationMillis: Int
)

private fun conversationSaleTaskButtonLabel(target: ConversationSaleTaskTarget?): String {
    return when (target?.checklistItemId) {
        "buyer-representative" -> "Choose buyer legal rep"
        "seller-representative" -> "Choose seller legal rep"
        "contract-packet" -> "Open contract packet"
        "workspace-invites" -> "Open invite step"
        "workspace-active" -> "Open legal workspace"
        "legal-review-pack" -> "Open legal review"
        "contract-signatures" -> "Open contract signing"
        "settlement-statement" -> "Open settlement statement"
        else -> "Open sale task"
    }
}

private fun conversationTaskTheme(target: ConversationSaleTaskTarget?): ConversationTaskTheme {
    return when (target?.checklistItemId) {
        "buyer-representative", "seller-representative" -> ConversationTaskTheme(
            accent = Color(0xFF0B6B7A),
            background = Color(0xFFE5F5F1),
            badgeBackground = Color(0x220B6B7A),
            badgeText = Color(0xFF0B6B7A),
            stageLabel = "LEGAL SETUP"
        )
        "contract-packet" -> ConversationTaskTheme(
            accent = Color(0xFF0A2433),
            background = Color(0xFFEAF4FB),
            badgeBackground = Color(0x220A2433),
            badgeText = Color(0xFF0A2433),
            stageLabel = "CONTRACT ISSUED"
        )
        "workspace-invites" -> ConversationTaskTheme(
            accent = Color(0xFFB25B00),
            background = Color(0xFFFFF4DD),
            badgeBackground = Color(0x33F0B429),
            badgeText = Color(0xFF8B5200),
            stageLabel = "INVITE DELIVERY"
        )
        "workspace-active" -> ConversationTaskTheme(
            accent = Color(0xFF189399),
            background = Color(0xFFEAF9FC),
            badgeBackground = Color(0x33189399),
            badgeText = Color(0xFF0B6B7A),
            stageLabel = "WORKSPACE LIVE"
        )
        "legal-review-pack" -> ConversationTaskTheme(
            accent = Color(0xFFD85D50),
            background = Color(0xFFFFEEEC),
            badgeBackground = Color(0x33D85D50),
            badgeText = Color(0xFFB0463B),
            stageLabel = "LEGAL REVIEW"
        )
        "contract-signatures" -> ConversationTaskTheme(
            accent = Color(0xFFB86B12),
            background = Color(0xFFFFF1D8),
            badgeBackground = Color(0x33F0B429),
            badgeText = Color(0xFF8B5200),
            stageLabel = "SIGNING"
        )
        "settlement-statement" -> ConversationTaskTheme(
            accent = Color(0xFF0B6B7A),
            background = Color(0xFFE3F6F0),
            badgeBackground = Color(0x220B6B7A),
            badgeText = Color(0xFF0B6B7A),
            stageLabel = "SETTLEMENT"
        )
        else -> ConversationTaskTheme(
            accent = Color(0xFF0B6B7A),
            background = Color(0xFFF4FAFD),
            badgeBackground = Color(0x220B6B7A),
            badgeText = Color(0xFF0B6B7A),
            stageLabel = "SALE TASK"
        )
    }
}

private fun conversationTaskLiveAnimationStyle(
    snapshot: SaleTaskLiveSnapshot?,
    emphasizeUrgentSnapshot: Boolean
): ConversationTaskLiveAnimationStyle {
    if (snapshot == null) {
        return ConversationTaskLiveAnimationStyle(
            enterScale = 0.97f,
            exitScale = 0.99f,
            enterDurationMillis = 180,
            exitDurationMillis = 150
        )
    }

    val normalizedSummary = snapshot.summary.lowercase(Locale.ROOT)
    val isUrgent = snapshot.tone == SaleTaskLiveSnapshotTone.CRITICAL ||
        normalizedSummary.contains("overdue") ||
        normalizedSummary.contains("follow-up") ||
        normalizedSummary.contains("follow up")

    if (isUrgent && emphasizeUrgentSnapshot) {
        return ConversationTaskLiveAnimationStyle(
            enterScale = 0.9f,
            exitScale = 1.03f,
            enterDurationMillis = 240,
            exitDurationMillis = 180
        )
    }

    if (snapshot.tone == SaleTaskLiveSnapshotTone.WARNING || isUrgent) {
        return ConversationTaskLiveAnimationStyle(
            enterScale = 0.94f,
            exitScale = 1.015f,
            enterDurationMillis = 210,
            exitDurationMillis = 165
        )
    }

    return ConversationTaskLiveAnimationStyle(
        enterScale = 0.97f,
        exitScale = 0.99f,
        enterDurationMillis = 180,
        exitDurationMillis = 150
    )
}

private fun conversationTaskSnapshotKey(snapshot: SaleTaskLiveSnapshot): String {
    return "${snapshot.tone.name}|${snapshot.summary}"
}

private fun conversationTaskNeedsUrgentFeedback(snapshot: SaleTaskLiveSnapshot): Boolean {
    val normalizedSummary = snapshot.summary.lowercase(Locale.ROOT)
    return snapshot.tone == SaleTaskLiveSnapshotTone.CRITICAL ||
        normalizedSummary.contains("overdue") ||
        normalizedSummary.contains("follow-up") ||
        normalizedSummary.contains("follow up")
}

private fun conversationTaskLiveStyle(snapshot: SaleTaskLiveSnapshot): ConversationTaskLiveStyle {
    return when (snapshot.tone) {
        SaleTaskLiveSnapshotTone.INFO -> ConversationTaskLiveStyle(
            tint = Color(0xFF0A2433),
            background = Color(0x220A2433),
            icon = Icons.Outlined.Description
        )
        SaleTaskLiveSnapshotTone.WARNING -> ConversationTaskLiveStyle(
            tint = Color(0xFFB25B00),
            background = Color(0x33F0B429),
            icon = Icons.Outlined.WarningAmber
        )
        SaleTaskLiveSnapshotTone.CRITICAL -> ConversationTaskLiveStyle(
            tint = Color(0xFFD85D50),
            background = Color(0x22D85D50),
            icon = Icons.Outlined.WarningAmber
        )
        SaleTaskLiveSnapshotTone.SUCCESS -> ConversationTaskLiveStyle(
            tint = Color(0xFF0B6B7A),
            background = Color(0x220B6B7A),
            icon = Icons.Outlined.CheckCircleOutline
        )
    }
}

private fun conversationTaskStatus(message: ConversationMessage): ConversationTaskStatus {
    val target = message.saleTaskTarget
    val normalizedBody = message.body.lowercase()

    fun containsAny(vararg fragments: String): Boolean {
        return fragments.any { normalizedBody.contains(it) }
    }

    if (containsAny("revoked", "expired", "no longer valid", "can no longer open")) {
        return ConversationTaskStatus(
            label = "Action needed",
            icon = Icons.Outlined.WarningAmber,
            tint = Color(0xFFD85D50),
            background = Color(0x22D85D50)
        )
    }

    if (containsAny("snoozed follow-up")) {
        return ConversationTaskStatus(
            label = "Snoozed",
            icon = Icons.Outlined.Schedule,
            tint = Color(0xFF0A2433),
            background = Color(0x2239B4DE)
        )
    }

    if (containsAny("completed follow-up")) {
        return ConversationTaskStatus(
            label = "Task cleared",
            icon = Icons.Outlined.CheckCircleOutline,
            tint = Color(0xFF0B6B7A),
            background = Color(0x220B6B7A)
        )
    }

    return when (target?.checklistItemId) {
        "buyer-representative", "seller-representative" -> {
            if (containsAny("selected", "chosen")) {
                ConversationTaskStatus(
                    label = "Representative set",
                    icon = Icons.Outlined.CheckCircleOutline,
                    tint = Color(0xFF0B6B7A),
                    background = Color(0x220B6B7A)
                )
            } else {
                ConversationTaskStatus(
                    label = "Needs selection",
                    icon = Icons.Outlined.Schedule,
                    tint = Color(0xFFB25B00),
                    background = Color(0x33F0B429)
                )
            }
        }
        "contract-packet" -> {
            if (containsAny("refreshed", "updated")) {
                ConversationTaskStatus(
                    label = "Packet refreshed",
                    icon = Icons.Outlined.Schedule,
                    tint = Color(0xFF189399),
                    background = Color(0x33189399)
                )
            } else {
                ConversationTaskStatus(
                    label = "Ready to review",
                    icon = Icons.Outlined.Description,
                    tint = Color(0xFF0A2433),
                    background = Color(0x220A2433)
                )
            }
        }
        "workspace-invites" -> {
            when {
                containsAny("follow up", "not been opened within 48 hours") -> ConversationTaskStatus(
                    label = "Follow up needed",
                    icon = Icons.Outlined.WarningAmber,
                    tint = Color(0xFFB25B00),
                    background = Color(0x33F0B429)
                )
                containsAny("resent", "shared") -> ConversationTaskStatus(
                    label = "Awaiting open",
                    icon = Icons.Outlined.Schedule,
                    tint = Color(0xFFB25B00),
                    background = Color(0x33F0B429)
                )
                containsAny("opened", "activated") -> ConversationTaskStatus(
                    label = "Invite opened",
                    icon = Icons.Outlined.CheckCircleOutline,
                    tint = Color(0xFF0B6B7A),
                    background = Color(0x220B6B7A)
                )
                else -> ConversationTaskStatus(
                    label = "Invite ready",
                    icon = Icons.Outlined.Email,
                    tint = Color(0xFFB25B00),
                    background = Color(0x33F0B429)
                )
            }
        }
        "workspace-active" -> {
            if (containsAny("acknowledged", "opened", "started reviewing")) {
                ConversationTaskStatus(
                    label = "Workspace live",
                    icon = Icons.Outlined.CheckCircleOutline,
                    tint = Color(0xFF0B6B7A),
                    background = Color(0x220B6B7A)
                )
            } else {
                ConversationTaskStatus(
                    label = "Awaiting first open",
                    icon = Icons.Outlined.LockOpen,
                    tint = Color(0xFF189399),
                    background = Color(0x33189399)
                )
            }
        }
        "legal-review-pack" -> {
            if (containsAny("uploaded", "reviewed", "settlement adjustment")) {
                ConversationTaskStatus(
                    label = "Review returned",
                    icon = Icons.Outlined.CheckCircleOutline,
                    tint = Color(0xFFD85D50),
                    background = Color(0x22D85D50)
                )
            } else {
                ConversationTaskStatus(
                    label = "Review pending",
                    icon = Icons.Outlined.Gavel,
                    tint = Color(0xFFD85D50),
                    background = Color(0x22D85D50)
                )
            }
        }
        "contract-signatures" -> {
            when {
                containsAny("both sides are now signed", "both buyer and seller have signed", "listing is now marked sold") -> ConversationTaskStatus(
                    label = "Fully signed",
                    icon = Icons.Outlined.CheckCircleOutline,
                    tint = Color(0xFF0B6B7A),
                    background = Color(0x220B6B7A)
                )
                containsAny("signed the contract packet") -> ConversationTaskStatus(
                    label = "Awaiting countersign",
                    icon = Icons.Outlined.Schedule,
                    tint = Color(0xFFB86B12),
                    background = Color(0x33F0B429)
                )
                else -> ConversationTaskStatus(
                    label = "Signatures needed",
                    icon = Icons.Outlined.WarningAmber,
                    tint = Color(0xFFB86B12),
                    background = Color(0x33F0B429)
                )
            }
        }
        "settlement-statement" -> {
            if (containsAny("ready", "uploaded", "shared")) {
                ConversationTaskStatus(
                    label = "Ready to settle",
                    icon = Icons.Outlined.CheckCircleOutline,
                    tint = Color(0xFF0B6B7A),
                    background = Color(0x220B6B7A)
                )
            } else {
                ConversationTaskStatus(
                    label = "Settlement next",
                    icon = Icons.Outlined.Description,
                    tint = Color(0xFF0A2433),
                    background = Color(0x220A2433)
                )
            }
        }
        else -> ConversationTaskStatus(
            label = "In progress",
            icon = Icons.Outlined.Description,
            tint = Color(0xFF0A2433),
            background = Color(0x220A2433)
        )
    }
}

private fun conversationSaleTaskIcon(target: ConversationSaleTaskTarget?): ImageVector {
    return when (target?.checklistItemId) {
        "buyer-representative", "seller-representative", "legal-review-pack" -> Icons.Outlined.Gavel
        "workspace-invites" -> Icons.Outlined.Email
        "workspace-active" -> Icons.Outlined.LockOpen
        else -> Icons.Outlined.Description
    }
}

private fun conversationSaleTaskTitle(target: ConversationSaleTaskTarget?): String {
    return when (target?.checklistItemId) {
        "buyer-representative" -> "Buyer legal representative"
        "seller-representative" -> "Seller legal representative"
        "contract-packet" -> "Contract packet"
        "workspace-invites" -> "Legal workspace invite"
        "workspace-active" -> "Legal workspace activity"
        "legal-review-pack" -> "Legal review pack"
        "contract-signatures" -> "Contract signing"
        "settlement-statement" -> "Settlement statement"
        else -> "Sale task"
    }
}

private fun conversationMessageDetailLines(message: ConversationMessage): List<String> {
    return message.body
        .lines()
        .map { it.trim() }
        .filter { it.isNotEmpty() }
}

private fun openLink(context: Context, destination: String) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(destination)).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    runCatching {
        context.startActivity(intent)
    }.getOrElse { error ->
        if (error !is ActivityNotFoundException) {
            throw error
        }
    }
}

private fun shareSaleDocument(context: Context, file: java.io.File, title: String) {
    val documentUri = androidx.core.content.FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        file
    )
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "application/pdf"
        putExtra(Intent.EXTRA_STREAM, documentUri)
        putExtra(Intent.EXTRA_SUBJECT, title)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    context.startActivity(Intent.createChooser(intent, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

private fun shareText(context: Context, title: String, text: String): Boolean {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, title)
        putExtra(Intent.EXTRA_TEXT, text)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    return runCatching {
        context.startActivity(Intent.createChooser(intent, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }.isSuccess
}

private fun formatAud(value: Int): String {
    return NumberFormat.getCurrencyInstance(Locale("en", "AU")).format(value)
}

private fun formatTimestamp(timestamp: Long): String {
    val formatter = SimpleDateFormat("d MMM yyyy, h:mm a", Locale.getDefault())
    return formatter.format(Date(timestamp))
}
