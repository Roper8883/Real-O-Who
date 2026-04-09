package com.realowho.app.marketplace

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.auth.MarketplaceRemoteException
import com.realowho.app.auth.MarketplaceUserProfile
import com.realowho.app.auth.UserRole
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.UUID
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlin.math.abs

class SaleCoordinationStore(
    context: Context,
    launchConfiguration: AppLaunchConfiguration,
    private val legalSearchService: LegalProfessionalSearchService = LegalProfessionalSearchServiceFactory.create(
        launchConfiguration
    ),
    private val syncService: SaleCoordinationSyncService = SaleCoordinationSyncServiceFactory.create(
        launchConfiguration
    )
) {
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
    }
    private val storageFile = File(
        File(context.filesDir, "real-o-who-marketplace"),
        "sale-coordination.json"
    )
    private val isEphemeral = launchConfiguration.isScreenshotMode

    var listing by mutableStateOf(SaleCoordinationSeed.listing)
        private set

    var offer by mutableStateOf(SaleCoordinationSeed.offer)
        private set

    var legalWorkspaceSession by mutableStateOf<LegalWorkspaceSession?>(null)
        private set

    init {
        if (!isEphemeral) {
            load()
        }
    }

    suspend fun searchLegalProfessionals(): List<LegalProfessional> {
        return legalSearchService.searchNear(listing)
    }

    suspend fun refreshFromBackend() {
        var didUpdateListing = false
        val remoteListing = runCatching {
            syncService.fetchListing(listing.id)
        }.getOrNull()
        if (remoteListing != null) {
            listing = remoteListing
            didUpdateListing = true
        }

        val remoteOffer = runCatching {
            syncService.fetchSale(listing.id)
        }.getOrNull()
        if (remoteOffer == null) {
            if (didUpdateListing) {
                persist()
            }
            return
        }

        offer = mergeOffer(remoteOffer)
        persist()
    }

    fun currentSelection(role: UserRole): LegalSelection? {
        return if (role == UserRole.BUYER) {
            offer.buyerLegalSelection
        } else {
            offer.sellerLegalSelection
        }
    }

    fun counterpartSelection(role: UserRole): LegalSelection? {
        return if (role == UserRole.BUYER) {
            offer.sellerLegalSelection
        } else {
            offer.buyerLegalSelection
        }
    }

    fun currentSelectionLabel(user: MarketplaceUserProfile): String {
        val selection = currentSelection(user.role) ?: return "Not selected yet"
        return selection.professional.name
    }

    suspend fun submitOffer(
        user: MarketplaceUserProfile,
        amount: Int,
        conditions: String
    ): OfferSubmissionOutcome {
        require(user.role == UserRole.BUYER) { "Only buyer accounts can submit offers." }
        require(offer.contractPacket?.isFullySigned != true) { "The sale is already complete." }

        val trimmedConditions = conditions.trim()
        require(amount > 0) { "Enter a valid offer amount." }
        require(trimmedConditions.isNotEmpty()) { "Add the offer conditions before sending." }

        val now = System.currentTimeMillis()
        val isRevision = offer.buyerId == user.id
        val offerMessage = "${user.name} ${if (isRevision) "updated" else "submitted"} an offer of ${formatAmount(amount)}. Conditions: $trimmedConditions"

        var updatedOffer = offer.copy(
            buyerId = user.id,
            amount = amount,
            conditions = trimmedConditions,
            createdAt = now,
            status = SaleOfferStatus.UNDER_OFFER
        )

        val updates = mutableListOf(
            SaleUpdateMessage(
                id = UUID.randomUUID().toString(),
                createdAt = now,
                title = if (isRevision) "Offer updated" else "Offer submitted",
                body = offerMessage
            )
        )

        var refreshedPacket: ContractPacket? = null
        if (updatedOffer.buyerLegalSelection != null && updatedOffer.sellerLegalSelection != null) {
            refreshedPacket = makeContractPacket(updatedOffer)
            updatedOffer = registerInitialWorkspaceMaterials(
                offer = updatedOffer,
                packet = refreshedPacket,
                uploadedBy = user
            )
            updates += SaleUpdateMessage(
                id = UUID.randomUUID().toString(),
                createdAt = now,
                title = if (offer.contractPacket == null) "Contract packet sent" else "Contract packet refreshed",
                body = refreshedPacket.summary
            )
        } else {
            updatedOffer = updatedOffer.copy(contractPacket = null)
        }

        updatedOffer = updatedOffer.copy(updates = updates + updatedOffer.updates)
        offer = updatedOffer
        persist()

        val syncedOffer = runCatching {
            syncService.upsertSale(updatedOffer)
        }.getOrNull()

        if (syncedOffer != null) {
            offer = mergeOffer(syncedOffer)
            persist()
        }

        return OfferSubmissionOutcome(
            offer = offer,
            contractPacket = refreshedPacket,
            isRevision = isRevision,
            threadMessage = offerMessage
        )
    }

    suspend fun respondToOffer(
        user: MarketplaceUserProfile,
        action: SellerOfferAction,
        amount: Int,
        conditions: String
    ): SellerOfferResponseOutcome {
        require(user.role == UserRole.SELLER) { "Only seller accounts can respond to offers." }
        require(offer.contractPacket?.isFullySigned != true) { "The sale is already complete." }

        val trimmedConditions = conditions.trim()
        require(amount > 0) { "Enter a valid offer amount." }
        require(trimmedConditions.isNotEmpty()) { "Add the sale terms before sending a response." }

        val now = System.currentTimeMillis()
        val nextStatus = when (action) {
            SellerOfferAction.ACCEPT -> SaleOfferStatus.ACCEPTED
            SellerOfferAction.REQUEST_CHANGES -> SaleOfferStatus.CHANGES_REQUESTED
            SellerOfferAction.COUNTER -> SaleOfferStatus.COUNTERED
        }

        var updatedOffer = offer.copy(
            sellerId = user.id,
            amount = amount,
            conditions = trimmedConditions,
            createdAt = now,
            status = nextStatus
        )

        val title = when (action) {
            SellerOfferAction.ACCEPT -> "Offer accepted"
            SellerOfferAction.REQUEST_CHANGES -> "Changes requested"
            SellerOfferAction.COUNTER -> "Counteroffer sent"
        }
        val threadMessage = when (action) {
            SellerOfferAction.ACCEPT -> {
                "${user.name} accepted the offer of ${formatAmount(amount)}. Terms confirmed: $trimmedConditions"
            }
            SellerOfferAction.REQUEST_CHANGES -> {
                "${user.name} requested changes before acceptance. Updated terms: $trimmedConditions"
            }
            SellerOfferAction.COUNTER -> {
                "${user.name} sent a counteroffer of ${formatAmount(amount)}. Updated terms: $trimmedConditions"
            }
        }

        val updates = mutableListOf(
            SaleUpdateMessage(
                id = UUID.randomUUID().toString(),
                createdAt = now,
                title = title,
                body = threadMessage
            )
        )

        var refreshedPacket: ContractPacket? = null
        if (updatedOffer.buyerLegalSelection != null && updatedOffer.sellerLegalSelection != null) {
            refreshedPacket = makeContractPacket(updatedOffer)
            updatedOffer = registerInitialWorkspaceMaterials(
                offer = updatedOffer,
                packet = refreshedPacket,
                uploadedBy = user
            )
            updates += SaleUpdateMessage(
                id = UUID.randomUUID().toString(),
                createdAt = now,
                title = if (offer.contractPacket == null) "Contract packet sent" else "Contract packet refreshed",
                body = refreshedPacket.summary
            )
        } else {
            updatedOffer = updatedOffer.copy(contractPacket = null)
        }

        updatedOffer = updatedOffer.copy(updates = updates + updatedOffer.updates)
        offer = updatedOffer
        persist()

        val syncedOffer = runCatching {
            syncService.upsertSale(updatedOffer)
        }.getOrNull()

        if (syncedOffer != null) {
            offer = mergeOffer(syncedOffer)
            persist()
        }

        val noticeMessage = when (action) {
            SellerOfferAction.ACCEPT -> "Offer accepted and synced to the shared sale workspace."
            SellerOfferAction.REQUEST_CHANGES -> "Requested changes were sent to the buyer."
            SellerOfferAction.COUNTER -> "Counteroffer sent to the buyer."
        }

        return SellerOfferResponseOutcome(
            offer = offer,
            contractPacket = refreshedPacket,
            threadMessage = threadMessage,
            noticeMessage = noticeMessage
        )
    }

    fun selectRepresentative(
        user: MarketplaceUserProfile,
        professional: LegalProfessional
    ): LegalSelectionResult {
        require(offer.contractPacket?.isFullySigned != true) { "The sale is already complete." }

        val selection = LegalSelection(
            role = user.role,
            selectedAt = System.currentTimeMillis(),
            professional = professional
        )

        val selectionChanged = when (user.role) {
            UserRole.BUYER -> offer.buyerLegalSelection?.professional?.id != professional.id
            UserRole.SELLER -> offer.sellerLegalSelection?.professional?.id != professional.id
        }

        var updatedOffer = when (user.role) {
            UserRole.BUYER -> offer.copy(
                buyerId = user.id,
                buyerLegalSelection = selection
            )
            UserRole.SELLER -> offer.copy(
                sellerId = user.id,
                sellerLegalSelection = selection
            )
        }

        updatedOffer = updatedOffer.copy(
            updates = listOf(
                SaleUpdateMessage(
                    id = UUID.randomUUID().toString(),
                    createdAt = System.currentTimeMillis(),
                    title = if (user.role == UserRole.BUYER) {
                        "Buyer representative selected"
                    } else {
                        "Seller representative selected"
                    },
                    body = "${user.name} chose ${professional.name} to handle the ${professional.primarySpecialty.lowercase()} side of the sale."
                )
            ) + updatedOffer.updates
        )

        var packet: ContractPacket? = null
        if (selectionChanged &&
            updatedOffer.buyerLegalSelection != null &&
            updatedOffer.sellerLegalSelection != null
        ) {
            packet = makeContractPacket(updatedOffer)
            updatedOffer = registerInitialWorkspaceMaterials(
                offer = updatedOffer,
                packet = packet,
                uploadedBy = user
            ).copy(
                updates = listOf(
                    SaleUpdateMessage(
                        id = UUID.randomUUID().toString(),
                        createdAt = System.currentTimeMillis(),
                        title = "Contract packet sent",
                        body = packet.summary
                    )
                ) + updatedOffer.updates
            )
        }

        offer = updatedOffer
        persist()
        return LegalSelectionResult(offer = updatedOffer, contractPacket = packet)
    }

    suspend fun signContractPacket(user: MarketplaceUserProfile): ContractSigningOutcome {
        require(offer.status == SaleOfferStatus.ACCEPTED) {
            "The seller needs to accept the offer before signing can begin."
        }

        val packet = requireNotNull(offer.contractPacket) {
            "The contract packet is not ready yet."
        }
        require(!packet.isFullySigned) { "The sale is already complete." }
        require(packet.signedAtFor(user) == null) { "You already signed this contract packet." }

        val now = System.currentTimeMillis()
        val updatedPacket = when (user.id) {
            packet.buyerId -> packet.copy(buyerSignedAt = packet.buyerSignedAt ?: now)
            packet.sellerId -> packet.copy(sellerSignedAt = packet.sellerSignedAt ?: now)
            else -> throw IllegalArgumentException("Only the buyer or seller can sign this contract packet.")
        }

        val signMessage = "${user.name} signed the contract packet and confirmed the private-sale terms."
        var updatedOffer = offer.copy(
            contractPacket = updatedPacket,
            updates = listOf(
                SaleUpdateMessage(
                    id = UUID.randomUUID().toString(),
                    createdAt = now,
                    title = if (user.role == UserRole.BUYER) {
                        "Buyer signed contract packet"
                    } else {
                        "Seller signed contract packet"
                    },
                    body = signMessage
                )
            ) + offer.updates
        )

        val didCompleteSale = updatedPacket.isFullySigned
        val threadMessage: String
        val noticeMessage: String

        if (didCompleteSale) {
            val completionMessage = "Both buyer and seller have signed the contract packet. The listing is now marked sold and the signed contract PDF is ready to share."
            updatedOffer = registerCompletionWorkspaceMaterials(
                offer = updatedOffer,
                packet = updatedPacket,
                uploadedBy = user,
                createdAt = now
            ).copy(
                updates = listOf(
                    SaleUpdateMessage(
                        id = UUID.randomUUID().toString(),
                        createdAt = now,
                        title = "Sale complete",
                        body = completionMessage
                    )
                ) + updatedOffer.updates
            )
            threadMessage = "${user.name} signed the contract packet. Both sides are now signed, the listing is marked sold, and the signed contract PDF is ready."
            noticeMessage = "Both sides have signed. The listing is now marked sold and the signed contract PDF is ready."
        } else {
            threadMessage = signMessage
            noticeMessage = "Your contract sign-off has been recorded."
        }

        offer = updatedOffer
        persist()

        val syncedOffer = runCatching {
            syncService.upsertSale(updatedOffer)
        }.getOrNull()

        if (syncedOffer != null) {
            offer = mergeOffer(syncedOffer)
            persist()
        }

        return ContractSigningOutcome(
            offer = offer,
            threadMessage = threadMessage,
            noticeMessage = noticeMessage,
            didCompleteSale = didCompleteSale
        )
    }

    suspend fun syncToBackend() {
        val syncedOffer = runCatching {
            syncService.upsertSale(offer)
        }.getOrNull() ?: return

        offer = mergeOffer(syncedOffer)
        persist()
    }

    fun recordReminderTimelineActivity(
        checklistItemId: String,
        actionTitle: String,
        triggeredBy: MarketplaceUserProfile,
        snoozedUntil: Long? = null
    ): ReminderTimelineActivityOutcome {
        val checklistItem = offer.settlementChecklist.firstOrNull { it.id == checklistItemId }
        val checklistTitle = checklistItem?.title ?: "Settlement checklist item"
        val createdAt = System.currentTimeMillis()
        val title: String
        val body: String
        val threadMessage: String

        if (snoozedUntil != null) {
            title = "Reminder snoozed"
            body = "${triggeredBy.name} snoozed the reminder for $checklistTitle until ${formatReminderTimelineTimestamp(snoozedUntil)}."
            threadMessage = "${triggeredBy.name} snoozed follow-up for $checklistTitle until ${formatReminderTimelineTimestamp(snoozedUntil)}."
        } else {
            val actionSummary = reminderActionNarrative(actionTitle)
            title = "Reminder completed"
            body = "${triggeredBy.name} cleared the reminder for $checklistTitle by $actionSummary."
            threadMessage = "${triggeredBy.name} completed follow-up for $checklistTitle by $actionSummary."
        }

        val latestUpdate = offer.updates.firstOrNull()
        if (
            latestUpdate?.kind == SaleUpdateKind.REMINDER &&
                latestUpdate.title == title &&
                latestUpdate.body == body &&
                abs(latestUpdate.createdAt - createdAt) < 10_000L
        ) {
            return ReminderTimelineActivityOutcome(
                offer = offer,
                threadMessage = threadMessage
            )
        }

        offer = offer.copy(
            updates = listOf(
                SaleUpdateMessage(
                    id = UUID.randomUUID().toString(),
                    createdAt = createdAt,
                    title = title,
                    body = body,
                    kind = SaleUpdateKind.REMINDER,
                    checklistItemId = checklistItemId
                )
            ) + offer.updates
        )
        persist()
        return ReminderTimelineActivityOutcome(
            offer = offer,
            threadMessage = threadMessage
        )
    }

    private fun reminderActionNarrative(activityTitle: String): String {
        return when (activityTitle.trim().lowercase()) {
            "representative follow-up completed" -> "completing representative follow-up"
            "contract packet follow-up completed" -> "completing contract packet follow-up"
            "invite sent" -> "sending the legal invite"
            "invite follow-up completed" -> "completing legal invite follow-up"
            "workspace access follow-up completed" -> "completing legal workspace access follow-up"
            "workspace receipt follow-up completed" -> "completing legal workspace receipt follow-up"
            "reviewed contract follow-up completed" -> "completing reviewed contract follow-up"
            "settlement adjustment follow-up completed" -> "completing settlement adjustment follow-up"
            "legal review follow-up completed" -> "completing legal review follow-up"
            "signature confirmed" -> "confirming the signature"
            "signature follow-up completed" -> "completing signature follow-up"
            "settlement statement follow-up completed" -> "completing settlement statement follow-up"
            "settlement follow-up completed" -> "completing settlement follow-up"
            else -> activityTitle.trim().lowercase()
        }
    }

    fun counterpartFor(user: MarketplaceUserProfile): MarketplaceUserProfile {
        return if (user.role == UserRole.SELLER) {
            MarketplaceUserProfile(
                id = offer.buyerId,
                name = "Noah Chen",
                role = UserRole.BUYER,
                suburb = "New Farm, QLD",
                headline = "Private buyer ready to move once the legal representatives are locked in.",
                verificationNote = "Finance pre-approval uploaded",
                createdAt = System.currentTimeMillis()
            )
        } else {
            MarketplaceUserProfile(
                id = offer.sellerId,
                name = "Mason Wright",
                role = UserRole.SELLER,
                suburb = "Wilston, QLD",
                headline = "Owner-managed private sale with no agent commission.",
                verificationNote = "Owner dashboard enabled",
                createdAt = System.currentTimeMillis()
            )
        }
    }

    suspend fun openLegalWorkspace(inviteCode: String): Boolean {
        val normalizedCode = inviteCode.trim().uppercase()
        require(normalizedCode.isNotEmpty()) { "Enter the invite code to continue." }

        val remoteWorkspace = try {
            syncService.fetchLegalWorkspace(normalizedCode)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                null
            } else {
                throw error
            }
        }

        if (remoteWorkspace != null) {
            if (remoteWorkspace.third.isRevoked) {
                throw IllegalStateException("This legal workspace invite has been revoked. Ask the buyer or seller to send a fresh invite.")
            }
            if (remoteWorkspace.third.isExpired) {
                throw IllegalStateException("This legal workspace invite has expired. Ask the buyer or seller to send a fresh invite.")
            }
            listing = remoteWorkspace.first
            offer = mergeOffer(remoteWorkspace.second)
            legalWorkspaceSession = remoteWorkspace.third.toSession(offer)
            persist()
            return true
        }

        val localInvite = offer.invites.firstOrNull { it.shareCode.equals(normalizedCode, ignoreCase = true) }
            ?: return false
        if (localInvite.isRevoked) {
            throw IllegalStateException("This legal workspace invite has been revoked. Ask the buyer or seller to send a fresh invite.")
        }
        if (localInvite.isExpired) {
            throw IllegalStateException("This legal workspace invite has expired. Ask the buyer or seller to send a fresh invite.")
        }
        val activatedInvite = activateInviteIfNeeded(localInvite)
        legalWorkspaceSession = activatedInvite.toSession(offer)
        return true
    }

    fun closeLegalWorkspace() {
        legalWorkspaceSession = null
    }

    fun currentLegalWorkspaceInvite(): SaleWorkspaceInvite? {
        val session = legalWorkspaceSession ?: return null
        return offer.invites.firstOrNull {
            it.id == session.inviteId || it.shareCode.equals(session.inviteCode, ignoreCase = true)
        }
    }

    fun acknowledgeLegalWorkspaceInvite(): LegalWorkspaceActionOutcome? {
        val session = legalWorkspaceSession ?: return null
        val inviteIndex = offer.invites.indexOfFirst {
            it.id == session.inviteId || it.shareCode.equals(session.inviteCode, ignoreCase = true)
        }
        if (inviteIndex < 0) {
            return null
        }

        val invite = offer.invites[inviteIndex]
        if (invite.acknowledgedAt != null) {
            return null
        }

        val acknowledgedAt = System.currentTimeMillis()
        val updatedInvite = invite.copy(acknowledgedAt = acknowledgedAt)
        val updatedInvites = offer.invites.toMutableList().apply {
            this[inviteIndex] = updatedInvite
        }
        val updateBody =
            "${updatedInvite.professionalName} acknowledged the ${updatedInvite.role.title.lowercase()} and confirmed they have started reviewing the sale documents."
        val updatedOffer = offer.copy(
            invites = updatedInvites,
            updates = listOf(
                SaleUpdateMessage(
                    id = UUID.randomUUID().toString(),
                    createdAt = acknowledgedAt,
                    title = "Legal workspace acknowledged",
                    body = updateBody
                )
            ) + offer.updates
        )

        offer = updatedOffer
        legalWorkspaceSession = updatedInvite.toSession(updatedOffer)
        persist()

        return LegalWorkspaceActionOutcome(
            offer = updatedOffer,
            representedPartyId = representedPartyId(updatedInvite.role, updatedOffer),
            checklistItemId = "workspace-active",
            threadMessage = updateBody,
            noticeMessage = "Receipt recorded. Buyer and seller can now see that the legal workspace is active."
        )
    }

    fun manageSaleInvite(
        role: LegalInviteRole,
        action: SaleInviteManagementAction,
        triggeredBy: MarketplaceUserProfile
    ): SaleInviteManagementOutcome? {
        val inviteIndex = offer.invites.indexOfFirst { it.role == role }
        if (inviteIndex < 0) {
            return null
        }

        val currentInvite = offer.invites[inviteIndex]
        val now = System.currentTimeMillis()
        val title: String
        val threadMessage: String
        val noticeMessage: String
        val updatedInvite: SaleWorkspaceInvite

        when (action) {
            SaleInviteManagementAction.REVOKE -> {
                if (currentInvite.revokedAt != null) {
                    return null
                }
                updatedInvite = currentInvite.copy(revokedAt = now)
                title = "Legal workspace invite revoked"
                threadMessage = "${updatedInvite.role.title} for ${updatedInvite.professionalName} was revoked. That invite code can no longer open the sale workspace."
                noticeMessage = "${updatedInvite.role.title} was revoked."
            }
            SaleInviteManagementAction.REGENERATE -> {
                updatedInvite = regenerateWorkspaceInvite(
                    currentInvite = currentInvite,
                    uploadedBy = triggeredBy,
                    createdAt = now
                )
                title = "Legal workspace invite regenerated"
                threadMessage = "${updatedInvite.role.title} for ${updatedInvite.professionalName} was regenerated. The previous invite code is no longer valid and a fresh code is ready to share."
                noticeMessage = "Fresh ${updatedInvite.role.title.lowercase()} is ready to resend."
            }
        }

        val updatedOffer = offer.copy(
            invites = offer.invites.toMutableList().apply {
                this[inviteIndex] = updatedInvite
            },
            updates = listOf(
                SaleUpdateMessage(
                    id = UUID.randomUUID().toString(),
                    createdAt = now,
                    title = title,
                    body = threadMessage
                )
            ) + offer.updates
        )

        offer = updatedOffer
        if (
            legalWorkspaceSession?.inviteId == currentInvite.id ||
                legalWorkspaceSession?.inviteCode.equals(currentInvite.shareCode, ignoreCase = true)
        ) {
            legalWorkspaceSession = if (action == SaleInviteManagementAction.REGENERATE) {
                updatedInvite.toSession(updatedOffer)
            } else {
                null
            }
        }
        persist()

        return SaleInviteManagementOutcome(
            offer = updatedOffer,
            invite = updatedInvite,
            threadMessage = threadMessage,
            noticeMessage = noticeMessage
        )
    }

    fun recordSaleInviteShare(
        role: LegalInviteRole,
        triggeredBy: MarketplaceUserProfile
    ): SaleInviteDeliveryOutcome? {
        val inviteIndex = offer.invites.indexOfFirst { it.role == role }
        if (inviteIndex < 0) {
            return null
        }

        val currentInvite = offer.invites[inviteIndex]
        if (currentInvite.isUnavailable) {
            return null
        }

        val now = System.currentTimeMillis()
        val updatedInvite = currentInvite.copy(
            lastSharedAt = now,
            shareCount = currentInvite.shareCount + 1
        )
        val isFirstShare = currentInvite.shareCount == 0
        val title = if (isFirstShare) "Legal workspace invite shared" else "Legal workspace invite resent"
        val threadMessage = if (isFirstShare) {
            "${updatedInvite.role.title} for ${updatedInvite.professionalName} was shared from the sale workspace. Follow up if the invite has not been opened within 48 hours."
        } else {
            "${updatedInvite.role.title} for ${updatedInvite.professionalName} was resent from the sale workspace. This invite has now been shared ${updatedInvite.shareCount} times."
        }
        val noticeMessage = if (isFirstShare) {
            "${updatedInvite.role.title} delivery is now being tracked."
        } else {
            "${updatedInvite.role.title} was resent. Follow up if it is not opened soon."
        }

        val updatedOffer = offer.copy(
            invites = offer.invites.toMutableList().apply {
                this[inviteIndex] = updatedInvite
            },
            updates = listOf(
                SaleUpdateMessage(
                    id = UUID.randomUUID().toString(),
                    createdAt = now,
                    title = title,
                    body = threadMessage
                )
            ) + offer.updates
        )

        offer = updatedOffer
        persist()

        return SaleInviteDeliveryOutcome(
            offer = updatedOffer,
            invite = updatedInvite,
            threadMessage = threadMessage,
            noticeMessage = noticeMessage
        )
    }

    fun uploadLegalWorkspaceDocument(
        kind: SaleDocumentKind,
        fileName: String,
        bytes: ByteArray,
        mimeType: String
    ): LegalWorkspaceActionOutcome? {
        val session = legalWorkspaceSession ?: return null
        val invite = currentLegalWorkspaceInvite() ?: return null
        val packet = offer.contractPacket ?: return null

        require(
            kind == SaleDocumentKind.REVIEWED_CONTRACT_PDF ||
                kind == SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF
        ) {
            "Unsupported legal workspace document."
        }

        val createdAt = System.currentTimeMillis()
        val document = makeLegalWorkspaceDocument(
            kind = kind,
            offer = offer,
            packet = packet,
            invite = invite,
            createdAt = createdAt,
            fileName = fileName,
            attachmentBase64 = java.util.Base64.getEncoder().encodeToString(bytes),
            mimeType = mimeType
        )
        var updatedOffer = upsertWorkspaceDocument(offer, document)
        val updateBody = when (kind) {
            SaleDocumentKind.REVIEWED_CONTRACT_PDF ->
                "${invite.professionalName} uploaded a reviewed contract PDF and highlighted the latest legal checks for the private sale."
            SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF ->
                "${invite.professionalName} uploaded a settlement adjustment PDF covering rates, balances, and final settlement notes."
            else -> return null
        }
        updatedOffer = updatedOffer.copy(
            updates = listOf(
                SaleUpdateMessage(
                    id = UUID.randomUUID().toString(),
                    createdAt = createdAt,
                    title = kind.title,
                    body = updateBody
                )
            ) + updatedOffer.updates
        )

        offer = updatedOffer
        legalWorkspaceSession = invite.toSession(updatedOffer)
        persist()

        return LegalWorkspaceActionOutcome(
            offer = updatedOffer,
            representedPartyId = representedPartyId(invite.role, updatedOffer),
            checklistItemId = if (kind == SaleDocumentKind.REVIEWED_CONTRACT_PDF) {
                "legal-review-pack"
            } else {
                "workspace-active"
            },
            threadMessage = updateBody,
            noticeMessage = if (kind == SaleDocumentKind.REVIEWED_CONTRACT_PDF) {
                "Reviewed contract PDF added to the shared sale documents."
            } else {
                "Settlement adjustment PDF added to the shared sale documents."
            }
        )
    }

    private fun makeContractPacket(updatedOffer: SaleOffer): ContractPacket {
        val buyerSelection = requireNotNull(updatedOffer.buyerLegalSelection)
        val sellerSelection = requireNotNull(updatedOffer.sellerLegalSelection)
        val amount = formatAmount(updatedOffer.amount)

        return ContractPacket(
            id = UUID.randomUUID().toString(),
            generatedAt = System.currentTimeMillis(),
            listingId = listing.id,
            offerId = updatedOffer.id,
            buyerId = updatedOffer.buyerId,
            sellerId = updatedOffer.sellerId,
            buyerRepresentative = buyerSelection.professional,
            sellerRepresentative = sellerSelection.professional,
            summary = "Contract packet prepared for $amount. Buyer legal representative: ${buyerSelection.professional.name}. Seller legal representative: ${sellerSelection.professional.name}. Next step: both parties review and sign through their chosen legal contacts.",
            buyerSignedAt = null,
            sellerSignedAt = null
        )
    }

    private fun mergeOffer(remoteOffer: SaleOffer): SaleOffer {
        return remoteOffer.copy(
            updates = if (remoteOffer.updates.isEmpty()) {
                offer.updates
            } else {
                remoteOffer.updates
            },
            invites = if (remoteOffer.invites.isEmpty()) {
                offer.invites
            } else {
                remoteOffer.invites
            },
            documents = if (remoteOffer.documents.isEmpty()) {
                offer.documents
            } else {
                remoteOffer.documents
            }
        )
    }

    private fun registerInitialWorkspaceMaterials(
        offer: SaleOffer,
        packet: ContractPacket,
        uploadedBy: MarketplaceUserProfile
    ): SaleOffer {
        var updatedOffer = offer.copy(contractPacket = packet)
        updatedOffer = upsertInvite(
            updatedOffer,
            makeWorkspaceInvite(LegalInviteRole.BUYER_REPRESENTATIVE, updatedOffer, packet, uploadedBy)
        )
        updatedOffer = upsertInvite(
            updatedOffer,
            makeWorkspaceInvite(LegalInviteRole.SELLER_REPRESENTATIVE, updatedOffer, packet, uploadedBy)
        )
        updatedOffer = appendDocument(
            updatedOffer,
            makeSaleDocument(SaleDocumentKind.CONTRACT_PACKET_PDF, updatedOffer, packet, uploadedBy, packet.generatedAt)
        )
        updatedOffer = appendDocument(
            updatedOffer,
            makeSaleDocument(SaleDocumentKind.COUNCIL_RATES_NOTICE_PDF, updatedOffer, packet, uploadedBy, packet.generatedAt)
        )
        updatedOffer = appendDocument(
            updatedOffer,
            makeSaleDocument(SaleDocumentKind.IDENTITY_CHECK_PACK_PDF, updatedOffer, packet, uploadedBy, packet.generatedAt)
        )
        return updatedOffer
    }

    private fun registerCompletionWorkspaceMaterials(
        offer: SaleOffer,
        packet: ContractPacket,
        uploadedBy: MarketplaceUserProfile,
        createdAt: Long
    ): SaleOffer {
        var updatedOffer = offer
        updatedOffer = appendDocument(
            updatedOffer,
            makeSaleDocument(SaleDocumentKind.SIGNED_CONTRACT_PDF, updatedOffer, packet, uploadedBy, createdAt)
        )
        updatedOffer = appendDocument(
            updatedOffer,
            makeSaleDocument(SaleDocumentKind.SETTLEMENT_STATEMENT_PDF, updatedOffer, packet, uploadedBy, createdAt)
        )
        return updatedOffer
    }

    private fun appendDocument(offer: SaleOffer, document: SaleDocument): SaleOffer {
        return offer.copy(documents = appendDocumentIfNeeded(offer.documents, document))
    }

    private fun upsertWorkspaceDocument(offer: SaleOffer, document: SaleDocument): SaleOffer {
        val documents = offer.documents.toMutableList()
        val existingIndex = documents.indexOfFirst {
            it.kind == document.kind && it.packetId == document.packetId
        }
        if (existingIndex >= 0) {
            documents[existingIndex] = document
        } else {
            documents.add(0, document)
        }
        return offer.copy(documents = documents)
    }

    private fun upsertInvite(offer: SaleOffer, invite: SaleWorkspaceInvite): SaleOffer {
        val invites = offer.invites.toMutableList()
        val existingIndex = invites.indexOfFirst { it.role == invite.role }
        if (existingIndex >= 0) {
            invites[existingIndex] = invite
        } else {
            invites.add(0, invite)
        }
        return offer.copy(invites = invites)
    }

    private fun appendDocumentIfNeeded(
        existing: List<SaleDocument>,
        document: SaleDocument
    ): List<SaleDocument> {
        if (existing.any { it.kind == document.kind && it.packetId == document.packetId }) {
            return existing
        }
        return listOf(document) + existing
    }

    private fun makeSaleDocument(
        kind: SaleDocumentKind,
        offer: SaleOffer,
        packet: ContractPacket,
        uploadedBy: MarketplaceUserProfile,
        createdAt: Long
    ): SaleDocument {
        val listingLabel = listing.address.suburb
            .lowercase()
            .replace(" ", "-")
            .replace(",", "")
        val suffix = when (kind) {
            SaleDocumentKind.CONTRACT_PACKET_PDF -> "contract-packet"
            SaleDocumentKind.COUNCIL_RATES_NOTICE_PDF -> "council-rates"
            SaleDocumentKind.IDENTITY_CHECK_PACK_PDF -> "identity-check-pack"
            SaleDocumentKind.SIGNED_CONTRACT_PDF -> "signed-contract"
            SaleDocumentKind.SETTLEMENT_STATEMENT_PDF -> "settlement-statement"
            SaleDocumentKind.REVIEWED_CONTRACT_PDF -> "reviewed-contract"
            SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF -> "settlement-adjustment"
        }
        val summary = when (kind) {
            SaleDocumentKind.CONTRACT_PACKET_PDF ->
                "Generated contract packet for ${formatAmount(offer.amount)} with both legal representatives attached."
            SaleDocumentKind.COUNCIL_RATES_NOTICE_PDF ->
                "Council rates notice for the property with current owner charges and due dates ready for legal review."
            SaleDocumentKind.IDENTITY_CHECK_PACK_PDF ->
                "Identity check pack covering buyer photo ID, seller ownership verification, and signing readiness."
            SaleDocumentKind.SIGNED_CONTRACT_PDF ->
                "Signed contract copy for ${formatAmount(offer.amount)} with both buyer and seller signatures recorded."
            SaleDocumentKind.SETTLEMENT_STATEMENT_PDF ->
                "Settlement statement for ${formatAmount(offer.amount)} with rates adjustments, balance due, and completion notes."
            SaleDocumentKind.REVIEWED_CONTRACT_PDF ->
                "Reviewed contract PDF with tracked legal notes and final review comments ready for buyer and seller sign-off."
            SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF ->
                "Settlement adjustment PDF with council rates adjustments, transfer balances, and final settlement figures."
        }

        return SaleDocument(
            id = UUID.randomUUID().toString(),
            kind = kind,
            createdAt = createdAt,
            fileName = "real-o-who-$suffix-$listingLabel.pdf",
            summary = summary,
            uploadedByUserId = uploadedBy.id,
            uploadedByName = uploadedBy.name,
            packetId = packet.id,
            mimeType = null,
            attachmentBase64 = null
        )
    }

    private fun makeWorkspaceInvite(
        role: LegalInviteRole,
        offer: SaleOffer,
        packet: ContractPacket,
        uploadedBy: MarketplaceUserProfile
    ): SaleWorkspaceInvite {
        val professional = if (role == LegalInviteRole.BUYER_REPRESENTATIVE) {
            packet.buyerRepresentative
        } else {
            packet.sellerRepresentative
        }
        val shareCode = makeWorkspaceInviteCode(role)
        val propertyLine = listing.address.fullLine
        val expiresAt = packet.generatedAt + LEGAL_WORKSPACE_INVITE_VALIDITY_MS
        val openLink = workspaceInviteOpenLink(shareCode)
        val shareMessage = """
            Real O Who legal workspace invite
            Invite code: $shareCode
            Property: $propertyLine
            Role: ${role.title}
            Professional: ${professional.name} (${professional.primarySpecialty})
            Open in the app: $openLink
            Valid until: ${legalInviteDate(expiresAt)}
            Tap the link above to open the legal workspace directly. If the app does not open automatically, enter invite code $shareCode from the Real O Who start screen.
            Use this invite to review the contract packet, council rates notice, identity check pack, and settlement documents for the private sale.
        """.trimIndent()

        return SaleWorkspaceInvite(
            id = UUID.randomUUID().toString(),
            role = role,
            createdAt = packet.generatedAt,
            professionalName = professional.name,
            professionalSpecialty = professional.primarySpecialty,
            shareCode = shareCode,
            shareMessage = shareMessage,
            expiresAt = expiresAt,
            activatedAt = null,
            revokedAt = null,
            acknowledgedAt = null,
            lastSharedAt = null,
            shareCount = 0,
            generatedByUserId = uploadedBy.id,
            generatedByName = uploadedBy.name
        )
    }

    private fun makeLegalWorkspaceDocument(
        kind: SaleDocumentKind,
        offer: SaleOffer,
        packet: ContractPacket,
        invite: SaleWorkspaceInvite,
        createdAt: Long,
        fileName: String,
        attachmentBase64: String,
        mimeType: String
    ): SaleDocument {
        val summary = when (kind) {
            SaleDocumentKind.REVIEWED_CONTRACT_PDF ->
                "${invite.professionalName} reviewed the latest contract packet and attached their marked-up contract guidance for the private sale."
            SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF ->
                "${invite.professionalName} uploaded settlement adjustments covering rates, balances, and the final settlement breakdown."
            else -> invite.shareMessage
        }

        return SaleDocument(
            id = UUID.randomUUID().toString(),
            kind = kind,
            createdAt = createdAt,
            fileName = fileName,
            summary = summary,
            uploadedByUserId = invite.id,
            uploadedByName = invite.professionalName,
            packetId = packet.id,
            mimeType = mimeType,
            attachmentBase64 = attachmentBase64
        )
    }

    private fun representedPartyId(role: LegalInviteRole, saleOffer: SaleOffer): String {
        return if (role == LegalInviteRole.BUYER_REPRESENTATIVE) {
            saleOffer.buyerId
        } else {
            saleOffer.sellerId
        }
    }

    private fun makeWorkspaceInviteCode(role: LegalInviteRole): String {
        val prefix = if (role == LegalInviteRole.BUYER_REPRESENTATIVE) "BUY" else "SEL"
        return "ROW-$prefix-${UUID.randomUUID().toString().replace("-", "").take(10).uppercase()}"
    }

    private fun workspaceInviteOpenLink(shareCode: String): String {
        return "realowho://legal-workspace?code=$shareCode"
    }

    private fun regenerateWorkspaceInvite(
        currentInvite: SaleWorkspaceInvite,
        uploadedBy: MarketplaceUserProfile,
        createdAt: Long
    ): SaleWorkspaceInvite {
        val shareCode = makeWorkspaceInviteCode(currentInvite.role)
        val expiresAt = createdAt + LEGAL_WORKSPACE_INVITE_VALIDITY_MS
        val openLink = workspaceInviteOpenLink(shareCode)
        val shareMessage = """
            Real O Who legal workspace invite
            Invite code: $shareCode
            Property: ${listing.address.fullLine}
            Role: ${currentInvite.role.title}
            Professional: ${currentInvite.professionalName} (${currentInvite.professionalSpecialty})
            Open in the app: $openLink
            Valid until: ${legalInviteDate(expiresAt)}
            Tap the link above to open the legal workspace directly. If the app does not open automatically, enter invite code $shareCode from the Real O Who start screen.
            Use this invite to review the contract packet, council rates notice, identity check pack, and settlement documents for the private sale.
        """.trimIndent()

        return SaleWorkspaceInvite(
            id = UUID.randomUUID().toString(),
            role = currentInvite.role,
            createdAt = createdAt,
            professionalName = currentInvite.professionalName,
            professionalSpecialty = currentInvite.professionalSpecialty,
            shareCode = shareCode,
            shareMessage = shareMessage,
            expiresAt = expiresAt,
            activatedAt = null,
            revokedAt = null,
            acknowledgedAt = null,
            lastSharedAt = null,
            shareCount = 0,
            generatedByUserId = uploadedBy.id,
            generatedByName = uploadedBy.name
        )
    }

    private suspend fun activateInviteIfNeeded(invite: SaleWorkspaceInvite): SaleWorkspaceInvite {
        if (invite.activatedAt != null) {
            return invite
        }

        val activatedAt = System.currentTimeMillis()
        val activatedInvite = invite.copy(activatedAt = activatedAt)
        offer = offer.copy(
            invites = offer.invites.map { existingInvite ->
                if (
                    existingInvite.id == invite.id ||
                    existingInvite.shareCode.equals(invite.shareCode, ignoreCase = true)
                ) {
                    activatedInvite
                } else {
                    existingInvite
                }
            },
            updates = listOf(
                SaleUpdateMessage(
                    id = UUID.randomUUID().toString(),
                    createdAt = activatedAt,
                    title = "Legal workspace opened",
                    body = "${activatedInvite.professionalName} opened the ${activatedInvite.role.title.lowercase()} using invite code ${activatedInvite.shareCode}."
                )
            ) + offer.updates
        )
        persist()
        runCatching { syncToBackend() }
        return activatedInvite
    }

    private fun formatReminderTimelineTimestamp(timestamp: Long): String {
        return SimpleDateFormat("d MMM, h:mm a", Locale.ENGLISH).format(timestamp)
    }

    private fun load() {
        runCatching {
            if (!storageFile.exists()) {
                return
            }

            val snapshot = json.decodeFromString<SaleCoordinationSnapshot>(storageFile.readText())
            listing = snapshot.listing
            offer = snapshot.offer
        }
    }

    private fun persist() {
        if (isEphemeral) {
            return
        }

        runCatching {
            storageFile.parentFile?.mkdirs()
            storageFile.writeText(
                json.encodeToString(
                    SaleCoordinationSnapshot(
                        listing = listing,
                        offer = offer
                    )
                )
            )
        }
    }

    private fun formatAmount(amount: Int): String {
        return "$" + "%,d".format(amount)
    }

    private fun legalInviteDate(timestamp: Long): String {
        return java.text.DateFormat.getDateInstance(java.text.DateFormat.MEDIUM).format(java.util.Date(timestamp))
    }

    private companion object {
        const val LEGAL_WORKSPACE_INVITE_VALIDITY_MS = 1000L * 60L * 60L * 24L * 30L
    }
}

data class ReminderTimelineActivityOutcome(
    val offer: SaleOffer,
    val threadMessage: String
)

private fun SaleWorkspaceInvite.toSession(offer: SaleOffer): LegalWorkspaceSession {
    return LegalWorkspaceSession(
        inviteId = id,
        listingId = offer.listingId,
        offerId = offer.id,
        inviteCode = shareCode,
        role = role,
        professionalName = professionalName
    )
}
