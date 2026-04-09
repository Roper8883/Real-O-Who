package com.realowho.app.marketplace

import com.realowho.app.auth.MarketplaceUserProfile
import com.realowho.app.auth.UserRole
import kotlinx.serialization.Serializable
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Serializable
data class SalePropertyAddress(
    val street: String,
    val suburb: String,
    val state: String,
    val postcode: String
) {
    val shortLine: String
        get() = "$street, $suburb"

    val fullLine: String
        get() = "$street, $suburb $state $postcode"
}

@Serializable
data class SaleListing(
    val id: String,
    val title: String,
    val summary: String,
    val address: SalePropertyAddress,
    val askingPrice: Int,
    val bedrooms: Int,
    val bathrooms: Int,
    val parkingSpaces: Int,
    val latitude: Double,
    val longitude: Double
) {
    val factLine: String
        get() = "$bedrooms bed • $bathrooms bath • $parkingSpaces car"
}

@Serializable
enum class LegalProfessionalSource(val title: String) {
    GOOGLE_PLACES("Google local listing"),
    LOCAL_FALLBACK("Offline local directory")
}

@Serializable
data class LegalProfessional(
    val id: String,
    val name: String,
    val specialties: List<String>,
    val address: String,
    val suburb: String,
    val phoneNumber: String? = null,
    val websiteUrl: String? = null,
    val mapsUrl: String? = null,
    val latitude: Double,
    val longitude: Double,
    val rating: Double? = null,
    val reviewCount: Int? = null,
    val source: LegalProfessionalSource,
    val searchSummary: String
) {
    val primarySpecialty: String
        get() = specialties.firstOrNull() ?: "Property law support"

    val sourceLine: String
        get() = "${source.title} • $suburb"
}

@Serializable
data class LegalSelection(
    val role: UserRole,
    val selectedAt: Long,
    val professional: LegalProfessional
)

@Serializable
data class ContractPacket(
    val id: String,
    val generatedAt: Long,
    val listingId: String,
    val offerId: String,
    val buyerId: String,
    val sellerId: String,
    val buyerRepresentative: LegalProfessional,
    val sellerRepresentative: LegalProfessional,
    val summary: String,
    val buyerSignedAt: Long? = null,
    val sellerSignedAt: Long? = null
) {
    val isFullySigned: Boolean
        get() = buyerSignedAt != null && sellerSignedAt != null

    fun signedAtFor(user: MarketplaceUserProfile): Long? {
        return when (user.id) {
            buyerId -> buyerSignedAt
            sellerId -> sellerSignedAt
            else -> null
        }
    }
}

const val LEGAL_WORKSPACE_INVITE_VALIDITY_MS = 1000L * 60L * 60L * 24L * 30L
const val LEGAL_WORKSPACE_INVITE_FOLLOW_UP_MS = 1000L * 60L * 60L * 48L

@Serializable
enum class LegalInviteRole(val title: String) {
    @kotlinx.serialization.SerialName("buyerRepresentative")
    BUYER_REPRESENTATIVE("Buyer legal rep access"),

    @kotlinx.serialization.SerialName("sellerRepresentative")
    SELLER_REPRESENTATIVE("Seller legal rep access");

    val audienceLabel: String
        get() = when (this) {
            BUYER_REPRESENTATIVE -> "Buyer legal rep"
            SELLER_REPRESENTATIVE -> "Seller legal rep"
        }
}

@Serializable
data class SaleWorkspaceInvite(
    val id: String,
    val role: LegalInviteRole,
    val createdAt: Long,
    val professionalName: String,
    val professionalSpecialty: String,
    val shareCode: String,
    val shareMessage: String,
    val expiresAt: Long = createdAt + LEGAL_WORKSPACE_INVITE_VALIDITY_MS,
    val activatedAt: Long? = null,
    val revokedAt: Long? = null,
    val acknowledgedAt: Long? = null,
    val lastSharedAt: Long? = null,
    val shareCount: Int = 0,
    val generatedByUserId: String,
    val generatedByName: String
)

@Serializable
enum class SaleDocumentKind(val title: String) {
    @kotlinx.serialization.SerialName("contractPacketPDF")
    CONTRACT_PACKET_PDF("Contract packet PDF"),

    @kotlinx.serialization.SerialName("councilRatesNoticePDF")
    COUNCIL_RATES_NOTICE_PDF("Council rates notice PDF"),

    @kotlinx.serialization.SerialName("identityCheckPackPDF")
    IDENTITY_CHECK_PACK_PDF("Identity check pack PDF"),

    @kotlinx.serialization.SerialName("signedContractPDF")
    SIGNED_CONTRACT_PDF("Signed contract PDF"),

    @kotlinx.serialization.SerialName("settlementStatementPDF")
    SETTLEMENT_STATEMENT_PDF("Settlement statement PDF"),

    @kotlinx.serialization.SerialName("reviewedContractPDF")
    REVIEWED_CONTRACT_PDF("Reviewed contract PDF"),

    @kotlinx.serialization.SerialName("settlementAdjustmentPDF")
    SETTLEMENT_ADJUSTMENT_PDF("Settlement adjustment PDF")
}

@Serializable
data class SaleDocument(
    val id: String,
    val kind: SaleDocumentKind,
    val createdAt: Long,
    val fileName: String,
    val summary: String,
    val uploadedByUserId: String,
    val uploadedByName: String,
    val packetId: String? = null,
    val mimeType: String? = null,
    val attachmentBase64: String? = null
)

@Serializable
data class SaleUpdateMessage(
    val id: String,
    val createdAt: Long,
    val title: String,
    val body: String,
    val kind: SaleUpdateKind = SaleUpdateKind.MILESTONE,
    val checklistItemId: String? = null
)

@Serializable
enum class SaleUpdateKind(val label: String) {
    @kotlinx.serialization.SerialName("milestone")
    MILESTONE("Milestone"),

    @kotlinx.serialization.SerialName("reminder")
    REMINDER("Reminder")
}

enum class SaleChecklistStatus(val title: String) {
    PENDING("Pending"),
    IN_PROGRESS("In progress"),
    COMPLETED("Done")
}

data class SaleChecklistItem(
    val id: String,
    val title: String,
    val detail: String,
    val ownerLabel: String,
    val targetAt: Long? = null,
    val nextAction: String? = null,
    val reminder: String? = null,
    val supporting: String? = null,
    val status: SaleChecklistStatus
)

val SaleChecklistItem.ownerSummary: String
    get() = "Owner: $ownerLabel"

val SaleChecklistItem.isOverdue: Boolean
    get() = status != SaleChecklistStatus.COMPLETED &&
        targetAt != null &&
        targetAt < System.currentTimeMillis()

val SaleChecklistItem.isDueSoon: Boolean
    get() = status != SaleChecklistStatus.COMPLETED &&
        targetAt != null &&
        !isOverdue &&
        targetAt < System.currentTimeMillis() + DAY_MS

val SaleChecklistItem.targetSummary: String?
    get() {
        if (status == SaleChecklistStatus.COMPLETED || targetAt == null) {
            return null
        }

        return when {
            isOverdue -> "Overdue since ${saleChecklistDate(targetAt)}"
            isDueSoon -> "Due soon: ${saleChecklistDate(targetAt)}"
            else -> "Target by ${saleChecklistDate(targetAt)}"
        }
    }

val SaleChecklistItem.nextActionSummary: String?
    get() = nextAction?.let { "Next: $it" }

val SaleChecklistItem.reminderSummary: String?
    get() = reminder?.let { "Reminder: $it" }

@Serializable
enum class SaleOfferStatus(val title: String) {
    @kotlinx.serialization.SerialName("underOffer")
    UNDER_OFFER("Under offer"),

    @kotlinx.serialization.SerialName("changesRequested")
    CHANGES_REQUESTED("Changes requested"),

    @kotlinx.serialization.SerialName("countered")
    COUNTERED("Counteroffer sent"),

    @kotlinx.serialization.SerialName("accepted")
    ACCEPTED("Accepted")
}

@Serializable
data class SaleOffer(
    val id: String,
    val listingId: String,
    val buyerId: String,
    val sellerId: String,
    val amount: Int,
    val conditions: String,
    val createdAt: Long,
    val status: SaleOfferStatus = SaleOfferStatus.UNDER_OFFER,
    val buyerLegalSelection: LegalSelection? = null,
    val sellerLegalSelection: LegalSelection? = null,
    val contractPacket: ContractPacket? = null,
    val invites: List<SaleWorkspaceInvite> = emptyList(),
    val documents: List<SaleDocument> = emptyList(),
    val updates: List<SaleUpdateMessage> = emptyList()
)

@Serializable
data class SaleCoordinationSnapshot(
    val listing: SaleListing,
    val offer: SaleOffer
)

data class LegalWorkspaceSession(
    val inviteId: String,
    val listingId: String,
    val offerId: String,
    val inviteCode: String,
    val role: LegalInviteRole,
    val professionalName: String
)

val SaleWorkspaceInvite.isExpired: Boolean
    get() = expiresAt < System.currentTimeMillis()

val SaleWorkspaceInvite.isRevoked: Boolean
    get() = revokedAt != null

val SaleWorkspaceInvite.isUnavailable: Boolean
    get() = isExpired || isRevoked

val SaleWorkspaceInvite.hasBeenShared: Boolean
    get() = shareCount > 0 || lastSharedAt != null

val SaleWorkspaceInvite.needsFollowUp: Boolean
    get() = !isUnavailable &&
        activatedAt == null &&
        lastSharedAt != null &&
        lastSharedAt + LEGAL_WORKSPACE_INVITE_FOLLOW_UP_MS < System.currentTimeMillis()

data class LegalSelectionResult(
    val offer: SaleOffer,
    val contractPacket: ContractPacket?
)

enum class SaleTaskLiveSnapshotTone {
    INFO,
    WARNING,
    CRITICAL,
    SUCCESS
}

data class SaleTaskLiveSnapshot(
    val summary: String,
    val tone: SaleTaskLiveSnapshotTone
)

data class SaleTaskSnapshotAudienceMember(
    val viewerId: String,
    val label: String
)

data class SaleTaskAudienceStatus(
    val seenBy: List<String>,
    val waitingOn: List<String>,
    val pending: List<String>,
    val seenEntries: List<SaleTaskAudienceSeenEntry>
)

data class SaleTaskAudienceSeenEntry(
    val label: String,
    val seenAt: Long
)

data class OfferSubmissionOutcome(
    val offer: SaleOffer,
    val contractPacket: ContractPacket?,
    val isRevision: Boolean,
    val threadMessage: String
)

enum class SellerOfferAction {
    ACCEPT,
    REQUEST_CHANGES,
    COUNTER
}

val SaleOffer.settlementChecklist: List<SaleChecklistItem>
    get() {
        val buyerInvite = inviteFor(LegalInviteRole.BUYER_REPRESENTATIVE)
        val sellerInvite = inviteFor(LegalInviteRole.SELLER_REPRESENTATIVE)
        val requiredInvites = listOfNotNull(buyerInvite, sellerInvite)
        val isLegallyCoordinated = buyerLegalSelection != null && sellerLegalSelection != null
        val expectedInviteCount = if (isLegallyCoordinated) 2 else requiredInvites.size
        val sharedInviteCount = requiredInvites.count { it.hasBeenShared }
        val activatedInviteCount = requiredInvites.count { it.activatedAt != null }
        val acknowledgedInviteCount = requiredInvites.count { it.acknowledgedAt != null }
        val followUpInviteCount = requiredInvites.count { it.needsFollowUp }
        val unavailableInviteCount = requiredInvites.count { it.isUnavailable }
        val latestSelectionDate = listOfNotNull(buyerLegalSelection?.selectedAt, sellerLegalSelection?.selectedAt).maxOrNull()
        val latestInviteSentDate = requiredInvites.mapNotNull { it.lastSharedAt }.maxOrNull()
        val latestInviteAcknowledgedDate = requiredInvites.mapNotNull { it.acknowledgedAt }.maxOrNull()
        val latestSignatureDate = listOfNotNull(contractPacket?.buyerSignedAt, contractPacket?.sellerSignedAt).maxOrNull()

        val documentKinds = documents.map { it.kind }.toSet()
        val hasReviewedContract = documentKinds.contains(SaleDocumentKind.REVIEWED_CONTRACT_PDF)
        val hasSettlementAdjustment = documentKinds.contains(SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF)
        val hasSettlementStatement = documentKinds.contains(SaleDocumentKind.SETTLEMENT_STATEMENT_PDF)
        val hasSignedContract = documentKinds.contains(SaleDocumentKind.SIGNED_CONTRACT_PDF)
        val legalReviewCount = listOf(hasReviewedContract, hasSettlementAdjustment).count { it }
        val signatureCount = listOf(contractPacket?.buyerSignedAt, contractPacket?.sellerSignedAt).count { it != null }
        val inviteSupporting = inviteSupporting(unavailableInviteCount, followUpInviteCount)

        return listOf(
            SaleChecklistItem(
                id = "buyer-representative",
                title = "Buyer legal rep chosen",
                detail = buyerLegalSelection?.let {
                    "${it.professional.name} selected ${saleChecklistDate(it.selectedAt)}."
                } ?: "Buyer still needs to choose a conveyancer, solicitor, or property lawyer.",
                ownerLabel = "Buyer",
                targetAt = createdAt + DAY_MS * 2,
                nextAction = if (buyerLegalSelection == null) {
                    "Choose a buyer-side conveyancer or solicitor."
                } else {
                    null
                },
                reminder = if (buyerLegalSelection == null && createdAt + DAY_MS * 2 < System.currentTimeMillis()) {
                    "The contract packet cannot start until the buyer chooses a representative."
                } else {
                    null
                },
                supporting = buyerLegalSelection?.professional?.primarySpecialty,
                status = if (buyerLegalSelection == null) SaleChecklistStatus.PENDING else SaleChecklistStatus.COMPLETED
            ),
            SaleChecklistItem(
                id = "seller-representative",
                title = "Seller legal rep chosen",
                detail = sellerLegalSelection?.let {
                    "${it.professional.name} selected ${saleChecklistDate(it.selectedAt)}."
                } ?: "Seller still needs to choose a conveyancer, solicitor, or property lawyer.",
                ownerLabel = "Seller",
                targetAt = createdAt + DAY_MS * 2,
                nextAction = if (sellerLegalSelection == null) {
                    "Choose a seller-side conveyancer or solicitor."
                } else {
                    null
                },
                reminder = if (sellerLegalSelection == null && createdAt + DAY_MS * 2 < System.currentTimeMillis()) {
                    "The contract packet cannot start until the seller chooses a representative."
                } else {
                    null
                },
                supporting = sellerLegalSelection?.professional?.primarySpecialty,
                status = if (sellerLegalSelection == null) SaleChecklistStatus.PENDING else SaleChecklistStatus.COMPLETED
            ),
            SaleChecklistItem(
                id = "contract-packet",
                title = "Contract packet issued",
                detail = contractPacket?.let {
                    "Contract packet issued ${saleChecklistDate(it.generatedAt)}."
                } ?: if (isLegallyCoordinated) {
                    "Legal reps are set. The contract packet is the next document to issue."
                } else {
                    "Both sides need legal reps before the contract packet can be issued."
                },
                ownerLabel = "Legal reps",
                targetAt = (latestSelectionDate ?: createdAt) + DAY_MS,
                nextAction = if (contractPacket == null && isLegallyCoordinated) {
                    "Issue the contract packet so both sides can move into signing."
                } else {
                    null
                },
                reminder = if (contractPacket == null && isLegallyCoordinated && (latestSelectionDate ?: createdAt) + DAY_MS < System.currentTimeMillis()) {
                    "The legal handoff is ready. Send the contract packet to avoid stalling the sale."
                } else {
                    null
                },
                supporting = contractPacket?.summary,
                status = when {
                    contractPacket != null -> SaleChecklistStatus.COMPLETED
                    isLegallyCoordinated -> SaleChecklistStatus.IN_PROGRESS
                    else -> SaleChecklistStatus.PENDING
                }
            ),
            SaleChecklistItem(
                id = "workspace-invites",
                title = "Legal workspace invites sent",
                detail = when {
                    expectedInviteCount == 0 ->
                        "Invites unlock once both sides have chosen a legal rep."
                    else ->
                        "$sharedInviteCount of $expectedInviteCount legal workspace invites have been sent."
                },
                ownerLabel = "Buyer and seller",
                targetAt = (contractPacket?.generatedAt ?: latestSelectionDate ?: createdAt) + HOUR_MS * 4,
                nextAction = when {
                    expectedInviteCount > 0 && sharedInviteCount < expectedInviteCount ->
                        "Share the latest invite link and code with each legal rep."
                    unavailableInviteCount > 0 ->
                        "Regenerate the expired or revoked invite before resending it."
                    followUpInviteCount > 0 ->
                        "Resend the invite or follow up directly."
                    else -> null
                },
                reminder = inviteSupporting,
                supporting = inviteSupporting,
                status = when {
                    expectedInviteCount == 0 -> SaleChecklistStatus.PENDING
                    sharedInviteCount == expectedInviteCount -> SaleChecklistStatus.COMPLETED
                    sharedInviteCount > 0 || requiredInvites.isNotEmpty() -> SaleChecklistStatus.IN_PROGRESS
                    else -> SaleChecklistStatus.PENDING
                }
            ),
            SaleChecklistItem(
                id = "workspace-active",
                title = "Legal workspace active",
                detail = when {
                    expectedInviteCount == 0 ->
                        "Once invites are sent, the legal reps can open and acknowledge the workspace."
                    acknowledgedInviteCount == expectedInviteCount ->
                        "All legal reps have opened and acknowledged the workspace."
                    else ->
                        "$activatedInviteCount of $expectedInviteCount opened • $acknowledgedInviteCount of $expectedInviteCount acknowledged."
                },
                ownerLabel = "Legal reps",
                targetAt = (latestInviteSentDate ?: contractPacket?.generatedAt ?: latestSelectionDate ?: createdAt) + DAY_MS * 2,
                nextAction = if (expectedInviteCount > 0 && acknowledgedInviteCount < expectedInviteCount) {
                    "Open the workspace invite and tap Acknowledge Receipt."
                } else {
                    null
                },
                reminder = when {
                    expectedInviteCount > 0 && acknowledgedInviteCount < expectedInviteCount && followUpInviteCount > 0 ->
                        "At least one legal rep still has not opened the workspace after the invite was sent."
                    expectedInviteCount > 0 && activatedInviteCount > 0 && acknowledgedInviteCount < expectedInviteCount ->
                        "A legal rep opened the workspace but has not acknowledged receipt yet."
                    else -> null
                },
                supporting = inviteSupporting,
                status = when {
                    expectedInviteCount == 0 -> SaleChecklistStatus.PENDING
                    acknowledgedInviteCount == expectedInviteCount -> SaleChecklistStatus.COMPLETED
                    activatedInviteCount > 0 || acknowledgedInviteCount > 0 || sharedInviteCount > 0 -> SaleChecklistStatus.IN_PROGRESS
                    else -> SaleChecklistStatus.PENDING
                }
            ),
            SaleChecklistItem(
                id = "legal-review-pack",
                title = "Legal review pack uploaded",
                detail = when (legalReviewCount) {
                    2 -> "Reviewed contract and settlement adjustment PDFs are attached."
                    1 -> "1 of 2 legal review PDFs is attached."
                    else -> "Legal reps can attach the reviewed contract and settlement adjustments here."
                },
                ownerLabel = "Legal reps",
                targetAt = (latestInviteAcknowledgedDate ?: contractPacket?.generatedAt ?: createdAt) + DAY_MS * 3,
                nextAction = reviewPackNextAction(hasReviewedContract, hasSettlementAdjustment),
                reminder = if (legalReviewCount < 2 && (latestInviteAcknowledgedDate ?: contractPacket?.generatedAt ?: createdAt) + DAY_MS * 3 < System.currentTimeMillis()) {
                    "The legal review pack is still incomplete, so contract changes may be waiting on upload."
                } else {
                    null
                },
                supporting = if (legalReviewCount == 2) {
                    null
                } else {
                    missingReviewPackSummary(hasReviewedContract, hasSettlementAdjustment)
                },
                status = when {
                    legalReviewCount == 2 -> SaleChecklistStatus.COMPLETED
                    legalReviewCount > 0 || acknowledgedInviteCount > 0 -> SaleChecklistStatus.IN_PROGRESS
                    else -> SaleChecklistStatus.PENDING
                }
            ),
            SaleChecklistItem(
                id = "contract-signatures",
                title = "Contract signed by both parties",
                detail = when {
                    contractPacket?.isFullySigned == true ->
                        "Buyer and seller signatures are both recorded."
                    contractPacket != null ->
                        "$signatureCount of 2 signatures recorded."
                    else ->
                        "Contract signatures start after the contract packet is issued."
                },
                ownerLabel = signatureOwnerLabel(contractPacket),
                targetAt = (contractPacket?.generatedAt ?: createdAt) + DAY_MS * 5,
                nextAction = signatureNextAction(contractPacket),
                reminder = if (contractPacket?.isFullySigned == false && (contractPacket?.generatedAt ?: createdAt) + DAY_MS * 5 < System.currentTimeMillis()) {
                    "The contract is still waiting on signatures. Follow up with the remaining party."
                } else {
                    null
                },
                supporting = if (contractPacket?.isFullySigned == true) {
                    null
                } else {
                    pendingSignatureSummary(contractPacket)
                },
                status = when {
                    contractPacket?.isFullySigned == true -> SaleChecklistStatus.COMPLETED
                    contractPacket != null -> SaleChecklistStatus.IN_PROGRESS
                    else -> SaleChecklistStatus.PENDING
                }
            ),
            SaleChecklistItem(
                id = "settlement-statement",
                title = "Settlement statement ready",
                detail = when {
                    hasSettlementStatement ->
                        "Settlement statement is attached in shared sale documents."
                    contractPacket?.isFullySigned == true || hasSignedContract ->
                        "The sale is signed. Settlement paperwork is being finalised."
                    else ->
                        "Settlement statement appears after both sides sign the contract."
                },
                ownerLabel = "Legal reps",
                targetAt = (latestSignatureDate ?: contractPacket?.generatedAt ?: createdAt) + DAY_MS * 2,
                nextAction = when {
                    hasSettlementStatement -> null
                    contractPacket?.isFullySigned == true || hasSignedContract ->
                        "Prepare and upload the settlement statement PDF."
                    else ->
                        "Complete both contract signatures before preparing settlement paperwork."
                },
                reminder = if (!hasSettlementStatement &&
                    (contractPacket?.isFullySigned == true || hasSignedContract) &&
                    (latestSignatureDate ?: contractPacket?.generatedAt ?: createdAt) + DAY_MS * 2 < System.currentTimeMillis()
                ) {
                    "Settlement paperwork is due. Upload the settlement statement to finish the file."
                } else {
                    null
                },
                supporting = if (!hasSettlementStatement && hasSignedContract) {
                    "The listing is already marked sold."
                } else {
                    null
                },
                status = when {
                    hasSettlementStatement -> SaleChecklistStatus.COMPLETED
                    contractPacket?.isFullySigned == true || hasSignedContract -> SaleChecklistStatus.IN_PROGRESS
                    else -> SaleChecklistStatus.PENDING
                }
            )
        )
    }

fun SaleOffer.liveTaskSnapshot(
    checklistItemId: String,
    now: Long = System.currentTimeMillis()
): SaleTaskLiveSnapshot? {
    val checklistItem = settlementChecklist.firstOrNull { it.id == checklistItemId } ?: return null
    val buyerInvite = inviteFor(LegalInviteRole.BUYER_REPRESENTATIVE)
    val sellerInvite = inviteFor(LegalInviteRole.SELLER_REPRESENTATIVE)
    val requiredInvites = listOfNotNull(buyerInvite, sellerInvite)
    val expectedInviteCount = if (buyerLegalSelection != null && sellerLegalSelection != null) 2 else requiredInvites.size
    val sharedInviteCount = requiredInvites.count { it.hasBeenShared }
    val activatedInviteCount = requiredInvites.count { it.activatedAt != null }
    val acknowledgedInviteCount = requiredInvites.count { it.acknowledgedAt != null }
    val followUpInvites = requiredInvites.filter { it.needsFollowUp }
    val unavailableInviteCount = requiredInvites.count { it.isUnavailable }

    val documentKinds = documents.map { it.kind }.toSet()
    val hasReviewedContract = documentKinds.contains(SaleDocumentKind.REVIEWED_CONTRACT_PDF)
    val hasSettlementAdjustment = documentKinds.contains(SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF)
    val hasSettlementStatement = documentKinds.contains(SaleDocumentKind.SETTLEMENT_STATEMENT_PDF)
    val hasSignedContract = documentKinds.contains(SaleDocumentKind.SIGNED_CONTRACT_PDF)
    val legalReviewCount = listOf(hasReviewedContract, hasSettlementAdjustment).count { it }
    val missingSignatureCount = listOf(contractPacket?.buyerSignedAt, contractPacket?.sellerSignedAt).count { it == null }

    return when (checklistItemId) {
        "buyer-representative", "seller-representative" -> {
            if (checklistItem.status == SaleChecklistStatus.COMPLETED) {
                SaleTaskLiveSnapshot("Representative selected", SaleTaskLiveSnapshotTone.SUCCESS)
            } else {
                SaleTaskLiveSnapshot(
                    summary = withDeadlineState("Representative still missing", checklistItem, now),
                    tone = if (checklistItem.isOverdue) SaleTaskLiveSnapshotTone.CRITICAL else SaleTaskLiveSnapshotTone.WARNING
                )
            }
        }
        "contract-packet" -> {
            when {
                contractPacket != null -> SaleTaskLiveSnapshot("Contract packet ready to review", SaleTaskLiveSnapshotTone.SUCCESS)
                buyerLegalSelection != null && sellerLegalSelection != null -> SaleTaskLiveSnapshot(
                    summary = withDeadlineState("Contract packet still needs issuing", checklistItem, now),
                    tone = if (checklistItem.isOverdue) SaleTaskLiveSnapshotTone.CRITICAL else SaleTaskLiveSnapshotTone.WARNING
                )
                else -> {
                    val repsLeft = listOf(buyerLegalSelection, sellerLegalSelection).count { it == null }
                    SaleTaskLiveSnapshot("$repsLeft legal rep${if (repsLeft == 1) "" else "s"} left before issue", SaleTaskLiveSnapshotTone.INFO)
                }
            }
        }
        "workspace-invites" -> {
            when {
                expectedInviteCount == 0 -> SaleTaskLiveSnapshot("Invites unlock after both reps are chosen", SaleTaskLiveSnapshotTone.INFO)
                unavailableInviteCount > 0 -> SaleTaskLiveSnapshot(
                    "$unavailableInviteCount invite${if (unavailableInviteCount == 1) "" else "s"} need regeneration",
                    SaleTaskLiveSnapshotTone.CRITICAL
                )
                followUpInvites.isNotEmpty() -> {
                    val overdueDays = followUpInvites.mapNotNull { invite ->
                        invite.lastSharedAt?.let { daysBetween(it + LEGAL_WORKSPACE_INVITE_FOLLOW_UP_MS, now) }
                    }.maxOrNull() ?: 1
                    val prefix = if (followUpInvites.size == 1) {
                        "1 invite needs follow-up"
                    } else {
                        "${followUpInvites.size} invites need follow-up"
                    }
                    SaleTaskLiveSnapshot(
                        "$prefix • $overdueDays day${if (overdueDays == 1) "" else "s"} overdue",
                        SaleTaskLiveSnapshotTone.WARNING
                    )
                }
                sharedInviteCount < expectedInviteCount -> {
                    val remaining = expectedInviteCount - sharedInviteCount
                    SaleTaskLiveSnapshot(
                        "$remaining invite${if (remaining == 1) "" else "s"} left to send",
                        SaleTaskLiveSnapshotTone.WARNING
                    )
                }
                activatedInviteCount < expectedInviteCount -> {
                    val remaining = expectedInviteCount - activatedInviteCount
                    SaleTaskLiveSnapshot(
                        "$remaining invite${if (remaining == 1) "" else "s"} left to open",
                        SaleTaskLiveSnapshotTone.INFO
                    )
                }
                acknowledgedInviteCount < expectedInviteCount -> {
                    val remaining = expectedInviteCount - acknowledgedInviteCount
                    SaleTaskLiveSnapshot(
                        "$remaining acknowledgement${if (remaining == 1) "" else "s"} left",
                        SaleTaskLiveSnapshotTone.INFO
                    )
                }
                else -> SaleTaskLiveSnapshot("Both legal reps acknowledged", SaleTaskLiveSnapshotTone.SUCCESS)
            }
        }
        "workspace-active" -> {
            when {
                expectedInviteCount == 0 -> SaleTaskLiveSnapshot("Waiting for invite delivery", SaleTaskLiveSnapshotTone.INFO)
                acknowledgedInviteCount == expectedInviteCount -> SaleTaskLiveSnapshot("All legal reps active in workspace", SaleTaskLiveSnapshotTone.SUCCESS)
                checklistItem.isOverdue -> {
                    val remaining = expectedInviteCount - acknowledgedInviteCount
                    SaleTaskLiveSnapshot(
                        withDeadlineState("$remaining acknowledgement${if (remaining == 1) "" else "s"} left", checklistItem, now),
                        SaleTaskLiveSnapshotTone.WARNING
                    )
                }
                activatedInviteCount == 0 -> SaleTaskLiveSnapshot(
                    "$expectedInviteCount legal rep${if (expectedInviteCount == 1) "" else "s"} still need to open",
                    SaleTaskLiveSnapshotTone.INFO
                )
                else -> {
                    val remaining = expectedInviteCount - acknowledgedInviteCount
                    SaleTaskLiveSnapshot(
                        "$remaining acknowledgement${if (remaining == 1) "" else "s"} left",
                        SaleTaskLiveSnapshotTone.INFO
                    )
                }
            }
        }
        "legal-review-pack" -> {
            when {
                legalReviewCount == 2 -> SaleTaskLiveSnapshot("Legal review pack complete", SaleTaskLiveSnapshotTone.SUCCESS)
                acknowledgedInviteCount == 0 -> SaleTaskLiveSnapshot("Waiting for legal review to begin", SaleTaskLiveSnapshotTone.INFO)
                else -> {
                    val remaining = 2 - legalReviewCount
                    SaleTaskLiveSnapshot(
                        withDeadlineState("$remaining review document${if (remaining == 1) "" else "s"} left", checklistItem, now),
                        if (checklistItem.isOverdue) SaleTaskLiveSnapshotTone.WARNING else SaleTaskLiveSnapshotTone.INFO
                    )
                }
            }
        }
        "contract-signatures" -> {
            when {
                contractPacket == null -> SaleTaskLiveSnapshot("Waiting for contract packet", SaleTaskLiveSnapshotTone.INFO)
                missingSignatureCount == 0 -> SaleTaskLiveSnapshot("Fully signed and ready to settle", SaleTaskLiveSnapshotTone.SUCCESS)
                else -> SaleTaskLiveSnapshot(
                    withDeadlineState("$missingSignatureCount signature${if (missingSignatureCount == 1) "" else "s"} left", checklistItem, now),
                    if (checklistItem.isOverdue) SaleTaskLiveSnapshotTone.WARNING else SaleTaskLiveSnapshotTone.INFO
                )
            }
        }
        "settlement-statement" -> {
            when {
                hasSettlementStatement -> SaleTaskLiveSnapshot("Settlement statement ready", SaleTaskLiveSnapshotTone.SUCCESS)
                contractPacket?.isFullySigned == true || hasSignedContract -> SaleTaskLiveSnapshot(
                    withDeadlineState("Settlement statement still pending", checklistItem, now),
                    if (checklistItem.isOverdue) SaleTaskLiveSnapshotTone.WARNING else SaleTaskLiveSnapshotTone.INFO
                )
                else -> SaleTaskLiveSnapshot("Settlement waits for final signing", SaleTaskLiveSnapshotTone.INFO)
            }
        }
        else -> null
    }
}

val SaleOffer.taskSnapshotAudienceMembers: List<SaleTaskSnapshotAudienceMember>
    get() {
        val audience = mutableListOf(
            SaleTaskSnapshotAudienceMember(
                viewerId = "user:$buyerId",
                label = "Buyer"
            ),
            SaleTaskSnapshotAudienceMember(
                viewerId = "user:$sellerId",
                label = "Seller"
            )
        )

        LegalInviteRole.entries.forEach { role ->
            val activeInvite = invites
                .filter { it.role == role && it.revokedAt == null }
                .maxByOrNull { it.createdAt }
                ?: invites
                    .filter { it.role == role }
                    .maxByOrNull { it.createdAt }

            if (activeInvite != null) {
                audience += SaleTaskSnapshotAudienceMember(
                    viewerId = "invite:${activeInvite.id}",
                    label = role.audienceLabel
                )
            }
        }

        return audience
    }

fun SaleOffer.taskSnapshotId(checklistItemId: String): String {
    return "$id|$checklistItemId"
}

private fun SaleOffer.inviteFor(role: LegalInviteRole): SaleWorkspaceInvite? {
    return invites
        .filter { it.role == role }
        .maxByOrNull { it.createdAt }
}

private fun saleChecklistDate(timestamp: Long): String {
    val formatter = SimpleDateFormat("d MMM yyyy", Locale.getDefault())
    return formatter.format(Date(timestamp))
}

private const val HOUR_MS = 1000L * 60L * 60L
private const val DAY_MS = HOUR_MS * 24L

private fun withDeadlineState(
    base: String,
    checklistItem: SaleChecklistItem,
    now: Long
): String {
    return when {
        checklistItem.isOverdue && checklistItem.targetAt != null -> {
            val overdueDays = daysBetween(checklistItem.targetAt, now)
            "$base • $overdueDays day${if (overdueDays == 1) "" else "s"} overdue"
        }
        checklistItem.isDueSoon -> "$base • due soon"
        else -> base
    }
}

private fun daysBetween(timestamp: Long, now: Long): Int {
    return maxOf(1, kotlin.math.ceil((now - timestamp).toDouble() / DAY_MS.toDouble()).toInt())
}

private fun inviteSupporting(
    unavailableInviteCount: Int,
    followUpInviteCount: Int
): String? {
    return when {
        unavailableInviteCount > 0 -> {
            val noun = if (unavailableInviteCount == 1) "invite needs" else "invites need"
            "$unavailableInviteCount $noun a fresh code."
        }
        followUpInviteCount > 0 -> {
            val noun = if (followUpInviteCount == 1) "invite still needs" else "invites still need"
            "$followUpInviteCount $noun follow-up."
        }
        else -> null
    }
}

private fun missingReviewPackSummary(
    hasReviewedContract: Boolean,
    hasSettlementAdjustment: Boolean
): String? {
    val missingItems = buildList {
        if (!hasReviewedContract) {
            add("reviewed contract")
        }
        if (!hasSettlementAdjustment) {
            add("settlement adjustment")
        }
    }

    return if (missingItems.isEmpty()) {
        null
    } else {
        "Still needed: ${missingItems.joinToString(" and ")}."
    }
}

private fun pendingSignatureSummary(packet: ContractPacket?): String? {
    packet ?: return null

    val pendingSides = buildList {
        if (packet.buyerSignedAt == null) {
            add("buyer")
        }
        if (packet.sellerSignedAt == null) {
            add("seller")
        }
    }

    return if (pendingSides.isEmpty()) {
        null
    } else {
        "Waiting on ${pendingSides.joinToString(" and ")} sign-off."
    }
}

private fun reviewPackNextAction(
    hasReviewedContract: Boolean,
    hasSettlementAdjustment: Boolean
): String? {
    return when {
        !hasReviewedContract && !hasSettlementAdjustment ->
            "Upload the reviewed contract and settlement adjustment PDFs."
        !hasReviewedContract ->
            "Upload the reviewed contract PDF."
        !hasSettlementAdjustment ->
            "Upload the settlement adjustment PDF."
        else -> null
    }
}

private fun signatureOwnerLabel(packet: ContractPacket?): String {
    packet ?: return "Buyer and seller"

    return when {
        packet.buyerSignedAt == null && packet.sellerSignedAt == null -> "Buyer and seller"
        packet.buyerSignedAt == null -> "Buyer"
        packet.sellerSignedAt == null -> "Seller"
        else -> "Buyer and seller"
    }
}

private fun signatureNextAction(packet: ContractPacket?): String? {
    packet ?: return null

    return when {
        packet.buyerSignedAt == null && packet.sellerSignedAt == null ->
            "Collect buyer and seller signatures on the contract packet."
        packet.buyerSignedAt == null ->
            "Buyer should sign the contract packet."
        packet.sellerSignedAt == null ->
            "Seller should sign the contract packet."
        else -> null
    }
}

data class SellerOfferResponseOutcome(
    val offer: SaleOffer,
    val contractPacket: ContractPacket?,
    val threadMessage: String,
    val noticeMessage: String
)

data class ContractSigningOutcome(
    val offer: SaleOffer,
    val threadMessage: String,
    val noticeMessage: String,
    val didCompleteSale: Boolean
)

data class LegalWorkspaceActionOutcome(
    val offer: SaleOffer,
    val representedPartyId: String,
    val checklistItemId: String,
    val threadMessage: String,
    val noticeMessage: String
)

enum class SaleInviteManagementAction {
    REGENERATE,
    REVOKE
}

data class SaleInviteManagementOutcome(
    val offer: SaleOffer,
    val invite: SaleWorkspaceInvite,
    val threadMessage: String,
    val noticeMessage: String
)

data class SaleInviteDeliveryOutcome(
    val offer: SaleOffer,
    val invite: SaleWorkspaceInvite,
    val threadMessage: String,
    val noticeMessage: String
)

object SaleCoordinationSeed {
    val listing = SaleListing(
        id = "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004",
        title = "Corner-block apartment with city skyline views",
        summary = "An upper-level apartment with panoramic views, oversized balcony, and a private-seller workflow built for fast shortlist-to-offer conversion.",
        address = SalePropertyAddress(
            street = "17/85 Moray Street",
            suburb = "New Farm",
            state = "QLD",
            postcode = "4005"
        ),
        askingPrice = 865_000,
        bedrooms = 2,
        bathrooms = 2,
        parkingSpaces = 1,
        latitude = -27.4685,
        longitude = 153.0459
    )

    val offer = SaleOffer(
        id = "8F69115B-988B-4F30-A5F1-8E0CF6A41001",
        listingId = listing.id,
        buyerId = "C8F18F9D-772E-4D62-8A88-0B9E23265002",
        sellerId = "C8F18F9D-772E-4D62-8A88-0B9E23265004",
        amount = 855_000,
        conditions = "Subject to finance approval and building and pest inspection.",
        createdAt = System.currentTimeMillis(),
        status = SaleOfferStatus.UNDER_OFFER,
        updates = listOf(
            SaleUpdateMessage(
                id = "sale-update-001",
                createdAt = System.currentTimeMillis(),
                title = "Offer received",
                body = "A private buyer has submitted an offer and both sides can now choose their legal representative."
            )
        )
    )
}
