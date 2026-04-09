package com.realowho.app.marketplace

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import com.realowho.app.auth.MarketplaceUserProfile
import org.json.JSONArray
import org.json.JSONObject

class SaleReminderScheduler(
    private val context: Context
) {
    data class ReminderActivityEntry(
        val createdAtMillis: Long,
        val title: String
    )

    private data class ReminderSpec(
        val id: String,
        val notificationId: Int,
        val title: String,
        val listingTitle: String,
        val body: String,
        val actionTitle: String,
        val completionActionTitle: String?,
        val completionActivityTitle: String?,
        val triggerAtMillis: Long,
        val priority: Int
    )

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun sync(
        currentUser: MarketplaceUserProfile,
        listing: SaleListing,
        offer: SaleOffer,
        notificationsAllowed: Boolean,
        taskSnapshotStore: ConversationTaskSnapshotSyncStore
    ) {
        if (!notificationsAllowed) {
            clearAll()
            return
        }

        ensureNotificationChannel(context)
        cleanupExpiredSnoozes()

        val reminders = reminderSpecs(
            currentUser = currentUser,
            listing = listing,
            offer = offer,
            taskSnapshotStore = taskSnapshotStore
        )
            .sortedWith(compareBy<ReminderSpec> { it.priority }.thenBy { it.triggerAtMillis })
            .take(6)

        val fingerprint = buildString {
            append(currentUser.id)
            reminders.forEach { reminder ->
                append("|")
                append(reminder.id)
                append("~")
                append(reminder.triggerAtMillis)
                append("~")
                append(reminder.body)
                append("~")
                append(reminder.actionTitle)
                append("~")
                append(reminder.completionActionTitle.orEmpty())
            }
        }

        if (prefs.getString(FINGERPRINT_KEY, null) == fingerprint) {
            return
        }

        clearAll()

        reminders.forEach { reminder ->
            val pendingIntent = pendingReminderIntent(
                context = context,
                reminderId = reminder.id,
                notificationId = reminder.notificationId,
                title = reminder.title,
                listingTitle = reminder.listingTitle,
                body = reminder.body,
                actionTitle = reminder.actionTitle,
                completionActionTitle = reminder.completionActionTitle,
                completionActivityTitle = reminder.completionActivityTitle
            )

            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                reminder.triggerAtMillis,
                pendingIntent
            )
        }

        prefs.edit()
            .putString(FINGERPRINT_KEY, fingerprint)
            .putStringSet(REMINDER_IDS_KEY, reminders.map { it.id }.toSet())
            .apply()
    }

    fun clearAll() {
        val reminderIDs = prefs.getStringSet(REMINDER_IDS_KEY, emptySet()).orEmpty()
        reminderIDs.forEach { reminderId ->
            alarmManager.cancel(
                pendingReminderIntent(
                    context = context,
                    reminderId = reminderId,
                    notificationId = reminderId.hashCode(),
                    title = "",
                    listingTitle = "",
                    body = "",
                    actionTitle = "",
                    completionActionTitle = null,
                    completionActivityTitle = null
                )
            )
            NotificationManagerCompat.from(context).cancel(reminderId.hashCode())
        }

        prefs.edit()
            .remove(FINGERPRINT_KEY)
            .remove(REMINDER_IDS_KEY)
            .apply()
    }

    fun clearReminder(offerId: String, checklistItemId: String) {
        val reminderId = "$offerId:$checklistItemId"
        cancelReminder(reminderId)
        clearSnooze(reminderId)

        val remainingReminderIds = prefs
            .getStringSet(REMINDER_IDS_KEY, emptySet())
            .orEmpty()
            .toMutableSet()
            .apply { remove(reminderId) }

        prefs.edit()
            .remove(FINGERPRINT_KEY)
            .putStringSet(REMINDER_IDS_KEY, remainingReminderIds)
            .apply()
    }

    fun clearReminder(
        offerId: String,
        checklistItemId: String,
        actionTitle: String
    ) {
        val reminderId = "$offerId:$checklistItemId"
        appendActivity(
            reminderId = reminderId,
            title = actionTitle
        )
        clearReminder(offerId, checklistItemId)
    }

    fun snoozeReminder(
        offerId: String,
        checklistItemId: String,
        durationMillis: Long,
        title: String = "Snoozed for 24 hours",
        snoozedUntilOverrideMillis: Long? = null
    ) {
        val reminderId = "$offerId:$checklistItemId"
        val snoozedUntil = snoozedUntilOverrideMillis ?: (System.currentTimeMillis() + durationMillis)
        prefs.edit()
            .putLong("${SNOOZE_PREFIX}$reminderId", snoozedUntil)
            .remove(FINGERPRINT_KEY)
            .apply()
        appendActivity(
            reminderId = reminderId,
            title = "$title until ${formatReminderTimestamp(snoozedUntil)}"
        )
        cancelReminder(reminderId)
    }

    fun snoozedUntil(offerId: String, checklistItemId: String): Long? {
        val reminderId = "$offerId:$checklistItemId"
        val value = prefs.getLong("${SNOOZE_PREFIX}$reminderId", -1L)
        return value.takeIf { it > System.currentTimeMillis() }
    }

    fun reminderActivity(offerId: String, checklistItemId: String): List<ReminderActivityEntry> {
        val reminderId = "$offerId:$checklistItemId"
        val payload = prefs.getString("${ACTIVITY_PREFIX}$reminderId", null) ?: return emptyList()
        return decodeActivity(payload)
    }

    private fun cancelReminder(reminderId: String) {
        alarmManager.cancel(
            pendingReminderIntent(
                context = context,
                    reminderId = reminderId,
                    notificationId = reminderId.hashCode(),
                    title = "",
                    listingTitle = "",
                    body = "",
                    actionTitle = "",
                    completionActionTitle = null,
                    completionActivityTitle = null
                )
            )
        NotificationManagerCompat.from(context).cancel(reminderId.hashCode())
    }

    private fun reminderSpecs(
        currentUser: MarketplaceUserProfile,
        listing: SaleListing,
        offer: SaleOffer,
        taskSnapshotStore: ConversationTaskSnapshotSyncStore
    ): List<ReminderSpec> {
        val now = System.currentTimeMillis()

        return offer.settlementChecklist.mapNotNull { item ->
            if (item.status == SaleChecklistStatus.COMPLETED) {
                return@mapNotNull null
            }

            val reminderId = "${offer.id}:${item.id}"
            if ((prefs.getLong("${SNOOZE_PREFIX}$reminderId", -1L)).let { it > now }) {
                return@mapNotNull null
            }

            val triggerAtMillis = when {
                item.isOverdue || item.reminderSummary != null -> now + IMMEDIATE_REMINDER_DELAY_MS
                item.targetAt != null -> maxOf(item.targetAt, now + IMMEDIATE_REMINDER_DELAY_MS)
                item.isDueSoon -> now + DUE_SOON_DELAY_MS
                else -> null
            } ?: return@mapNotNull null

            val audienceContext = taskSnapshotStore.reminderNotificationContext(
                snapshot = offer.liveTaskSnapshot(item.id, now),
                taskId = offer.taskSnapshotId(item.id),
                audience = offer.taskSnapshotAudienceMembers,
                now = now
            )
            val trailingContext = audienceContext ?: buildString {
                append(item.ownerSummary)
                if (currentUser.role.name.lowercase() !in item.ownerLabel.lowercase() &&
                    item.ownerLabel != "Buyer and seller" &&
                    item.ownerLabel != "Legal reps"
                ) {
                    append(" Visible to ${currentUser.role.name.lowercase()} for follow-up.")
                }
            }
            val body = buildString {
                append(item.reminderSummary ?: item.nextActionSummary ?: item.detail)
                append(" ")
                append(trailingContext)
            }

            ReminderSpec(
                id = reminderId,
                notificationId = reminderId.hashCode(),
                title = item.title,
                listingTitle = listing.title,
                body = body,
                actionTitle = reminderActionTitle(
                    item = item,
                    offer = offer,
                    currentUser = currentUser
                ),
                completionActionTitle = reminderQuickCompletionDescriptor(
                    item = item,
                    offer = offer,
                    currentUser = currentUser
                )?.actionTitle,
                completionActivityTitle = reminderQuickCompletionDescriptor(
                    item = item,
                    offer = offer,
                    currentUser = currentUser
                )?.activityTitle,
                triggerAtMillis = triggerAtMillis,
                priority = reminderPriority(item)
            )
        }
    }

    private data class ReminderQuickCompletionDescriptor(
        val actionTitle: String,
        val activityTitle: String
    )

    private fun reminderActionTitle(
        item: SaleChecklistItem,
        offer: SaleOffer,
        currentUser: MarketplaceUserProfile
    ): String {
        val viewerIsBuyer = currentUser.id == offer.buyerId || (
            currentUser.id != offer.sellerId &&
                currentUser.role == com.realowho.app.auth.UserRole.BUYER
            )
        val needsFollowUp = item.isOverdue || item.reminderSummary != null
        val ownInviteRole = if (viewerIsBuyer) {
            LegalInviteRole.BUYER_REPRESENTATIVE
        } else {
            LegalInviteRole.SELLER_REPRESENTATIVE
        }
        val counterpartInviteRole = if (viewerIsBuyer) {
            LegalInviteRole.SELLER_REPRESENTATIVE
        } else {
            LegalInviteRole.BUYER_REPRESENTATIVE
        }
        val ownInvite = latestInvite(offer, ownInviteRole)
        val counterpartInvite = latestInvite(offer, counterpartInviteRole)
        val hasReviewedContract = offer.documents.any { it.kind == SaleDocumentKind.REVIEWED_CONTRACT_PDF }
        val hasSettlementAdjustment = offer.documents.any { it.kind == SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF }
        val hasSettlementStatement = offer.documents.any { it.kind == SaleDocumentKind.SETTLEMENT_STATEMENT_PDF }
        val hasSignedContract = offer.documents.any { it.kind == SaleDocumentKind.SIGNED_CONTRACT_PDF }

        return when (item.id) {
            "buyer-representative" -> {
                if (viewerIsBuyer) {
                    if (offer.buyerLegalSelection == null) "Choose your legal rep" else "Review your legal rep"
                } else {
                    if (offer.buyerLegalSelection == null) {
                        if (needsFollowUp) "Follow up with buyer" else "Check buyer legal rep"
                    } else {
                        "Review buyer legal rep"
                    }
                }
            }

            "seller-representative" -> {
                if (!viewerIsBuyer) {
                    if (offer.sellerLegalSelection == null) "Choose your legal rep" else "Review your legal rep"
                } else {
                    if (offer.sellerLegalSelection == null) {
                        if (needsFollowUp) "Follow up with seller" else "Check seller legal rep"
                    } else {
                        "Review seller legal rep"
                    }
                }
            }

            "contract-packet" -> {
                if (offer.contractPacket != null) {
                    "Review contract packet"
                } else if (needsFollowUp) {
                    "Follow up on contract packet"
                } else {
                    "Check contract packet status"
                }
            }

            "workspace-invites" -> when {
                ownInvite?.isUnavailable == true -> "Refresh your legal invite"
                ownInvite != null && !ownInvite.hasBeenShared -> "Send your legal invite"
                ownInvite?.needsFollowUp == true -> "Follow up with your legal rep"
                counterpartInvite?.isUnavailable == true ->
                    if (viewerIsBuyer) "Check seller rep invite" else "Check buyer rep invite"
                counterpartInvite != null && !counterpartInvite.hasBeenShared ->
                    if (viewerIsBuyer) "Check seller rep invite" else "Check buyer rep invite"
                counterpartInvite?.needsFollowUp == true ->
                    if (viewerIsBuyer) "Follow up with seller rep" else "Follow up with buyer rep"
                else -> "Manage legal invites"
            }

            "workspace-active" -> when {
                ownInvite != null && ownInvite.activatedAt == null -> "Follow up with your legal rep"
                ownInvite != null && ownInvite.acknowledgedAt == null -> "Check your rep receipt"
                counterpartInvite != null && counterpartInvite.activatedAt == null ->
                    if (viewerIsBuyer) "Follow up with seller rep" else "Follow up with buyer rep"
                counterpartInvite != null && counterpartInvite.acknowledgedAt == null ->
                    if (viewerIsBuyer) "Check seller rep receipt" else "Check buyer rep receipt"
                else -> "Open legal workspace"
            }

            "legal-review-pack" -> {
                if (hasReviewedContract && hasSettlementAdjustment) {
                    "Review legal review pack"
                } else if (needsFollowUp) {
                    "Follow up on legal review"
                } else {
                    "Check legal review pack"
                }
            }

            "contract-signatures" -> {
                val packet = offer.contractPacket
                when {
                    packet == null -> "Check signing status"
                    packet.isFullySigned -> "Review signed contract"
                    viewerIsBuyer && packet.buyerSignedAt == null -> "Sign contract now"
                    !viewerIsBuyer && packet.sellerSignedAt == null -> "Sign contract now"
                    viewerIsBuyer && packet.sellerSignedAt == null ->
                        if (needsFollowUp) "Follow up with seller" else "Check seller signature"
                    !viewerIsBuyer && packet.buyerSignedAt == null ->
                        if (needsFollowUp) "Follow up with buyer" else "Check buyer signature"
                    else -> "Open contract signing"
                }
            }

            "settlement-statement" -> when {
                hasSettlementStatement -> "Review settlement statement"
                offer.contractPacket?.isFullySigned == true || hasSignedContract ->
                    if (needsFollowUp) "Follow up on settlement" else "Check settlement status"
                else -> "Open settlement step"
            }

            else -> "Open sale task"
        }
    }

    private fun latestInvite(
        offer: SaleOffer,
        role: LegalInviteRole
    ): SaleWorkspaceInvite? {
        return offer.invites
            .filter { it.role == role }
            .maxByOrNull { it.createdAt }
    }

    private fun reminderQuickCompletionDescriptor(
        item: SaleChecklistItem,
        offer: SaleOffer,
        currentUser: MarketplaceUserProfile
    ): ReminderQuickCompletionDescriptor? {
        val viewerIsBuyer = currentUser.id == offer.buyerId || (
            currentUser.id != offer.sellerId &&
                currentUser.role == com.realowho.app.auth.UserRole.BUYER
            )
        val ownInviteRole = if (viewerIsBuyer) {
            LegalInviteRole.BUYER_REPRESENTATIVE
        } else {
            LegalInviteRole.SELLER_REPRESENTATIVE
        }
        val counterpartInviteRole = if (viewerIsBuyer) {
            LegalInviteRole.SELLER_REPRESENTATIVE
        } else {
            LegalInviteRole.BUYER_REPRESENTATIVE
        }
        val ownInvite = latestInvite(offer, ownInviteRole)
        val counterpartInvite = latestInvite(offer, counterpartInviteRole)
        val hasReviewedContract = offer.documents.any { it.kind == SaleDocumentKind.REVIEWED_CONTRACT_PDF }
        val hasSettlementAdjustment = offer.documents.any { it.kind == SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF }
        val hasSettlementStatement = offer.documents.any { it.kind == SaleDocumentKind.SETTLEMENT_STATEMENT_PDF }
        val inviteParty = reminderInviteFocusParty(offer, currentUser)
        val workspaceParty = reminderWorkspaceFocusParty(offer, currentUser)
        val signatureParty = reminderSignatureFocusParty(offer, currentUser)

        return when (item.id) {
            "buyer-representative", "seller-representative" ->
                ReminderQuickCompletionDescriptor(
                    actionTitle = if (item.id == "buyer-representative") {
                        "Mark Buyer Rep Follow-Up Done"
                    } else {
                        "Mark Seller Rep Follow-Up Done"
                    },
                    activityTitle = "Representative follow-up completed"
                )

            "contract-packet" ->
                if (offer.contractPacket == null &&
                    offer.buyerLegalSelection != null &&
                    offer.sellerLegalSelection != null
                ) {
                    ReminderQuickCompletionDescriptor(
                        actionTitle = "Mark Contract Packet Follow-Up Done",
                        activityTitle = "Contract packet follow-up completed"
                    )
                } else {
                    null
                }

            "workspace-invites" ->
                when {
                    ownInvite?.isUnavailable == true -> null
                    ownInvite != null && !ownInvite.hasBeenShared ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark $inviteParty Rep Invite Sent",
                            activityTitle = "Invite sent"
                        )
                    else ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark $inviteParty Rep Invite Follow-Up Done",
                            activityTitle = "Invite follow-up completed"
                        )
                }

            "workspace-active" ->
                when {
                    ownInvite != null && ownInvite.activatedAt == null ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark $workspaceParty Rep Access Follow-Up Done",
                            activityTitle = "Workspace access follow-up completed"
                        )
                    ownInvite != null && ownInvite.acknowledgedAt == null ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark $workspaceParty Rep Receipt Follow-Up Done",
                            activityTitle = "Workspace receipt follow-up completed"
                        )
                    counterpartInvite != null && counterpartInvite.activatedAt == null ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark $workspaceParty Rep Access Follow-Up Done",
                            activityTitle = "Workspace access follow-up completed"
                        )
                    counterpartInvite != null && counterpartInvite.acknowledgedAt == null ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark $workspaceParty Rep Receipt Follow-Up Done",
                            activityTitle = "Workspace receipt follow-up completed"
                        )
                    else -> null
                }

            "legal-review-pack" ->
                when {
                    !hasReviewedContract ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark Reviewed Contract Follow-Up Done",
                            activityTitle = "Reviewed contract follow-up completed"
                        )
                    !hasSettlementAdjustment ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark Settlement Adjustment Follow-Up Done",
                            activityTitle = "Settlement adjustment follow-up completed"
                        )
                    else ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark Review Follow-Up Done",
                            activityTitle = "Legal review follow-up completed"
                        )
                }

            "contract-signatures" -> {
                val packet = offer.contractPacket
                when {
                    packet == null -> null
                    viewerIsBuyer && packet.buyerSignedAt == null ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark Buyer Signature Confirmed",
                            activityTitle = "Signature confirmed"
                        )
                    !viewerIsBuyer && packet.sellerSignedAt == null ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark Seller Signature Confirmed",
                            activityTitle = "Signature confirmed"
                        )
                    else ->
                        ReminderQuickCompletionDescriptor(
                            actionTitle = "Mark $signatureParty Signature Follow-Up Done",
                            activityTitle = "Signature follow-up completed"
                        )
                }
            }

            "settlement-statement" ->
                if (!hasSettlementStatement) {
                    ReminderQuickCompletionDescriptor(
                        actionTitle = "Mark Settlement Statement Follow-Up Done",
                        activityTitle = "Settlement statement follow-up completed"
                    )
                } else {
                    ReminderQuickCompletionDescriptor(
                        actionTitle = "Mark Settlement Follow-Up Done",
                        activityTitle = "Settlement follow-up completed"
                    )
                }

            else -> null
        }
    }

    private fun reminderInviteFocusParty(
        offer: SaleOffer,
        currentUser: MarketplaceUserProfile
    ): String {
        val viewerIsBuyer = currentUser.id == offer.buyerId || (
            currentUser.id != offer.sellerId &&
                currentUser.role == com.realowho.app.auth.UserRole.BUYER
            )
        val ownRole = if (viewerIsBuyer) {
            LegalInviteRole.BUYER_REPRESENTATIVE
        } else {
            LegalInviteRole.SELLER_REPRESENTATIVE
        }
        val counterpartRole = if (viewerIsBuyer) {
            LegalInviteRole.SELLER_REPRESENTATIVE
        } else {
            LegalInviteRole.BUYER_REPRESENTATIVE
        }

        val ownInvite = latestInvite(offer, ownRole)
        if (ownInvite != null &&
            (ownInvite.isUnavailable || !ownInvite.hasBeenShared || ownInvite.needsFollowUp)
        ) {
            return if (viewerIsBuyer) "Buyer" else "Seller"
        }

        val counterpartInvite = latestInvite(offer, counterpartRole)
        if (counterpartInvite != null &&
            (counterpartInvite.isUnavailable || !counterpartInvite.hasBeenShared || counterpartInvite.needsFollowUp)
        ) {
            return if (viewerIsBuyer) "Seller" else "Buyer"
        }

        return if (viewerIsBuyer) "Buyer" else "Seller"
    }

    private fun reminderWorkspaceFocusParty(
        offer: SaleOffer,
        currentUser: MarketplaceUserProfile
    ): String {
        val viewerIsBuyer = currentUser.id == offer.buyerId || (
            currentUser.id != offer.sellerId &&
                currentUser.role == com.realowho.app.auth.UserRole.BUYER
            )
        val ownRole = if (viewerIsBuyer) {
            LegalInviteRole.BUYER_REPRESENTATIVE
        } else {
            LegalInviteRole.SELLER_REPRESENTATIVE
        }
        val counterpartRole = if (viewerIsBuyer) {
            LegalInviteRole.SELLER_REPRESENTATIVE
        } else {
            LegalInviteRole.BUYER_REPRESENTATIVE
        }

        val ownInvite = latestInvite(offer, ownRole)
        if (ownInvite != null && (ownInvite.activatedAt == null || ownInvite.acknowledgedAt == null)) {
            return if (viewerIsBuyer) "Buyer" else "Seller"
        }

        val counterpartInvite = latestInvite(offer, counterpartRole)
        if (counterpartInvite != null &&
            (counterpartInvite.activatedAt == null || counterpartInvite.acknowledgedAt == null)
        ) {
            return if (viewerIsBuyer) "Seller" else "Buyer"
        }

        return if (viewerIsBuyer) "Buyer" else "Seller"
    }

    private fun reminderSignatureFocusParty(
        offer: SaleOffer,
        currentUser: MarketplaceUserProfile
    ): String {
        val viewerIsBuyer = currentUser.id == offer.buyerId || (
            currentUser.id != offer.sellerId &&
                currentUser.role == com.realowho.app.auth.UserRole.BUYER
            )
        val packet = offer.contractPacket ?: return if (viewerIsBuyer) "Buyer" else "Seller"

        return when {
            viewerIsBuyer && packet.buyerSignedAt != null && packet.sellerSignedAt == null -> "Seller"
            !viewerIsBuyer && packet.sellerSignedAt != null && packet.buyerSignedAt == null -> "Buyer"
            viewerIsBuyer -> "Buyer"
            else -> "Seller"
        }
    }

    private fun reminderPriority(item: SaleChecklistItem): Int {
        return when {
            item.isOverdue -> 0
            item.reminderSummary != null -> 1
            item.isDueSoon -> 2
            item.status == SaleChecklistStatus.IN_PROGRESS -> 3
            else -> 4
        }
    }

    companion object {
        private const val PREFS_NAME = "real_o_who_sale_reminders"
        private const val FINGERPRINT_KEY = "fingerprint"
        private const val REMINDER_IDS_KEY = "reminder_ids"
        private const val SNOOZE_PREFIX = "snooze_"
        private const val ACTIVITY_PREFIX = "activity_"
        private const val IMMEDIATE_REMINDER_DELAY_MS = 15_000L
        private const val DUE_SOON_DELAY_MS = 30L * 60L * 1000L

        const val CHANNEL_ID = "real_o_who_sale_reminders"
        const val EXTRA_REMINDER_ID = "extra_reminder_id"
        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_LISTING_TITLE = "extra_listing_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_ACTION_TITLE = "extra_action_title"
        const val EXTRA_COMPLETION_ACTION_TITLE = "extra_completion_action_title"
        const val EXTRA_COMPLETION_ACTIVITY_TITLE = "extra_completion_activity_title"

        fun ensureNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                return
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existingChannel = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existingChannel != null) {
                return
            }

            notificationManager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Sale reminders",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Settlement checklist reminders and legal follow-up nudges."
                }
            )
        }

        fun pendingReminderIntent(
            context: Context,
            reminderId: String,
            notificationId: Int,
            title: String,
            listingTitle: String,
            body: String,
            actionTitle: String,
            completionActionTitle: String?,
            completionActivityTitle: String?
        ): PendingIntent {
            val intent = Intent(context, SaleReminderReceiver::class.java).apply {
                action = ACTION_SHOW_REMINDER
                putExtra(EXTRA_REMINDER_ID, reminderId)
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_LISTING_TITLE, listingTitle)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_ACTION_TITLE, actionTitle)
                putExtra(EXTRA_COMPLETION_ACTION_TITLE, completionActionTitle)
                putExtra(EXTRA_COMPLETION_ACTIVITY_TITLE, completionActivityTitle)
            }

            return PendingIntent.getBroadcast(
                context,
                reminderId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun snoozeReminderIntent(
            context: Context,
            reminderId: String,
            notificationId: Int
        ): PendingIntent {
            val intent = Intent(context, SaleReminderReceiver::class.java).apply {
                action = ACTION_SNOOZE_REMINDER
                putExtra(EXTRA_REMINDER_ID, reminderId)
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            }

            return PendingIntent.getBroadcast(
                context,
                reminderId.hashCode() xor 0x51A7E,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun completeReminderIntent(
            context: Context,
            reminderId: String,
            notificationId: Int,
            activityTitle: String
        ): PendingIntent {
            val intent = Intent(context, SaleReminderReceiver::class.java).apply {
                action = ACTION_COMPLETE_REMINDER
                putExtra(EXTRA_REMINDER_ID, reminderId)
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_COMPLETION_ACTIVITY_TITLE, activityTitle)
            }

            return PendingIntent.getBroadcast(
                context,
                reminderId.hashCode() xor 0xA11CE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        const val ACTION_SHOW_REMINDER = "com.realowho.sale.reminder.SHOW"
        const val ACTION_COMPLETE_REMINDER = "com.realowho.sale.reminder.COMPLETE"
        const val ACTION_SNOOZE_REMINDER = "com.realowho.sale.reminder.SNOOZE"
    }

    private fun clearSnooze(reminderId: String) {
        prefs.edit()
            .remove("${SNOOZE_PREFIX}$reminderId")
            .apply()
    }

    private fun cleanupExpiredSnoozes() {
        val now = System.currentTimeMillis()
        val editor = prefs.edit()
        prefs.all.keys
            .filter { it.startsWith(SNOOZE_PREFIX) }
            .forEach { key ->
                val value = prefs.getLong(key, -1L)
                if (value in 0 until now) {
                    editor.remove(key)
                }
            }
        editor.apply()
    }

    private fun appendActivity(
        reminderId: String,
        title: String
    ) {
        val existing = reminderActivity(
            offerId = reminderId.substringBefore(':'),
            checklistItemId = reminderId.substringAfter(':')
        ).toMutableList()
        existing.add(
            0,
            ReminderActivityEntry(
                createdAtMillis = System.currentTimeMillis(),
                title = title
            )
        )

        val payload = JSONArray().apply {
            existing.take(6).forEach { entry ->
                put(
                    JSONObject()
                        .put("createdAtMillis", entry.createdAtMillis)
                        .put("title", entry.title)
                )
            }
        }

        prefs.edit()
            .putString("${ACTIVITY_PREFIX}$reminderId", payload.toString())
            .apply()
    }

    private fun decodeActivity(payload: String): List<ReminderActivityEntry> {
        val array = runCatching { JSONArray(payload) }.getOrNull() ?: return emptyList()
        return buildList {
            for (index in 0 until array.length()) {
                val entry = array.optJSONObject(index) ?: continue
                add(
                    ReminderActivityEntry(
                        createdAtMillis = entry.optLong("createdAtMillis"),
                        title = entry.optString("title")
                    )
                )
            }
        }
    }

    private fun formatReminderTimestamp(timestampMillis: Long): String {
        return java.text.DateFormat.getDateTimeInstance(
            java.text.DateFormat.MEDIUM,
            java.text.DateFormat.SHORT
        ).format(java.util.Date(timestampMillis))
    }
}
