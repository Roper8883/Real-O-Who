package com.realowho.app.marketplace

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.MainActivity
import com.realowho.app.auth.MarketplaceSessionStore
import com.realowho.app.auth.MarketplaceUserProfile
import com.realowho.app.auth.UserRole
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class SaleReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SaleReminderScheduler.ensureNotificationChannel(context)

        val reminderId = intent.getStringExtra(SaleReminderScheduler.EXTRA_REMINDER_ID)
        val notificationId = intent.getIntExtra(
            SaleReminderScheduler.EXTRA_NOTIFICATION_ID,
            0
        )
        if (intent.action == SaleReminderScheduler.ACTION_SNOOZE_REMINDER) {
            val offerId = reminderId?.substringBefore(':')?.takeIf { it.isNotBlank() }
            val checklistItemId = reminderId
                ?.substringAfterLast(':', "")
                ?.takeIf { it.isNotBlank() }
            val pendingResult = goAsync()

            CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
                try {
                    var feedbackTitle: String? = null
                    var feedbackListingTitle: String? = null
                    var feedbackBody: String? = null
                    if (offerId != null && checklistItemId != null) {
                        val appContext = context.applicationContext
                        val launchConfiguration = AppLaunchConfiguration.fromIntent(null)
                        val scheduler = SaleReminderScheduler(appContext)
                        val sessionStore = MarketplaceSessionStore(appContext, launchConfiguration)
                        val saleStore = SaleCoordinationStore(appContext, launchConfiguration)
                        val conversationStore = ConversationStore(appContext, launchConfiguration)
                        val snoozeDurationMillis = 24L * 60L * 60L * 1000L
                        val snoozedUntil = System.currentTimeMillis() + snoozeDurationMillis

                        if (sessionStore.isAuthenticated && saleStore.offer.id == offerId) {
                            val user = sessionStore.currentUser
                            val counterpart = saleStore.counterpartFor(user)
                            val reminderOutcome = saleStore.recordReminderTimelineActivity(
                                checklistItemId = checklistItemId,
                                actionTitle = "Snoozed from notification",
                                triggeredBy = user,
                                snoozedUntil = snoozedUntil
                            )
                            saleStore.syncToBackend()
                            conversationStore.sendMessage(
                                listing = saleStore.listing,
                                sender = user,
                                recipient = counterpart,
                                body = reminderOutcome.threadMessage,
                                isSystem = true,
                                saleTaskTarget = ConversationSaleTaskTarget(
                                    listingId = saleStore.listing.id,
                                    offerId = saleStore.offer.id,
                                    checklistItemId = checklistItemId
                                )
                            )
                            val feedback = snoozeFeedbackCopy(
                                checklistItemId = checklistItemId,
                                snoozedUntil = snoozedUntil,
                                offer = saleStore.offer,
                                currentUser = user
                            )
                            feedbackTitle = feedback.title
                            feedbackListingTitle = saleStore.listing.title
                            feedbackBody = feedback.body
                        }

                        scheduler.snoozeReminder(
                            offerId = offerId,
                            checklistItemId = checklistItemId,
                            durationMillis = snoozeDurationMillis,
                            title = "Snoozed for 24 hours from notification",
                            snoozedUntilOverrideMillis = snoozedUntil
                        )
                    }
                    if (feedbackTitle != null && feedbackListingTitle != null && feedbackBody != null) {
                        showActionFeedbackNotification(
                            context = context,
                            notificationId = notificationId,
                            title = feedbackTitle,
                            listingTitle = feedbackListingTitle,
                            body = feedbackBody,
                            checklistItemId = checklistItemId
                        )
                    } else {
                        NotificationManagerCompat.from(context).cancel(notificationId)
                    }
                } finally {
                    pendingResult.finish()
                }
            }
            return
        }
        if (intent.action == SaleReminderScheduler.ACTION_COMPLETE_REMINDER) {
            val offerId = reminderId?.substringBefore(':')?.takeIf { it.isNotBlank() }
            val checklistItemId = reminderId
                ?.substringAfterLast(':', "")
                ?.takeIf { it.isNotBlank() }
            val activityTitle = intent.getStringExtra(
                SaleReminderScheduler.EXTRA_COMPLETION_ACTIVITY_TITLE
            ) ?: "Reminder completed"
            val pendingResult = goAsync()

            CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
                try {
                    var feedbackTitle: String? = null
                    var feedbackListingTitle: String? = null
                    var feedbackBody: String? = null
                    if (offerId != null && checklistItemId != null) {
                        val appContext = context.applicationContext
                        val launchConfiguration = AppLaunchConfiguration.fromIntent(null)
                        val scheduler = SaleReminderScheduler(appContext)
                        val sessionStore = MarketplaceSessionStore(appContext, launchConfiguration)
                        val saleStore = SaleCoordinationStore(appContext, launchConfiguration)
                        val conversationStore = ConversationStore(appContext, launchConfiguration)

                        if (sessionStore.isAuthenticated && saleStore.offer.id == offerId) {
                            val user = sessionStore.currentUser
                            val counterpart = saleStore.counterpartFor(user)
                            val reminderOutcome = saleStore.recordReminderTimelineActivity(
                                checklistItemId = checklistItemId,
                                actionTitle = activityTitle,
                                triggeredBy = user
                            )
                            saleStore.syncToBackend()
                            conversationStore.sendMessage(
                                listing = saleStore.listing,
                                sender = user,
                                recipient = counterpart,
                                body = reminderOutcome.threadMessage,
                                isSystem = true,
                                saleTaskTarget = ConversationSaleTaskTarget(
                                    listingId = saleStore.listing.id,
                                    offerId = saleStore.offer.id,
                                    checklistItemId = checklistItemId
                                )
                            )
                            val feedback = completionFeedbackCopy(
                                checklistItemId = checklistItemId,
                                activityTitle = activityTitle,
                                offer = saleStore.offer,
                                currentUser = user
                            )
                            feedbackTitle = feedback.title
                            feedbackListingTitle = saleStore.listing.title
                            feedbackBody = feedback.body
                        }

                        scheduler.clearReminder(
                            offerId = offerId,
                            checklistItemId = checklistItemId,
                            actionTitle = activityTitle
                        )
                    }
                    if (feedbackTitle != null && feedbackListingTitle != null && feedbackBody != null) {
                        showActionFeedbackNotification(
                            context = context,
                            notificationId = notificationId,
                            title = feedbackTitle,
                            listingTitle = feedbackListingTitle,
                            body = feedbackBody,
                            checklistItemId = checklistItemId
                        )
                    } else {
                        NotificationManagerCompat.from(context).cancel(notificationId)
                    }
                } finally {
                    pendingResult.finish()
                }
            }
            return
        }

        val title = intent.getStringExtra(SaleReminderScheduler.EXTRA_TITLE)
            ?: "Sale follow-up due"
        val listingTitle = intent.getStringExtra(SaleReminderScheduler.EXTRA_LISTING_TITLE)
            ?: "Private sale workspace"
        val body = intent.getStringExtra(SaleReminderScheduler.EXTRA_BODY)
            ?: "A settlement checklist item needs attention."
        val actionTitle = intent.getStringExtra(SaleReminderScheduler.EXTRA_ACTION_TITLE)
            ?: "Open sale task"
        val completionActionTitle = intent.getStringExtra(
            SaleReminderScheduler.EXTRA_COMPLETION_ACTION_TITLE
        )
        val completionActivityTitle = intent.getStringExtra(
            SaleReminderScheduler.EXTRA_COMPLETION_ACTIVITY_TITLE
        )
        val resolvedNotificationId = if (notificationId == 0) title.hashCode() else notificationId
        val checklistItemId = reminderId
            ?.substringAfterLast(':', "")
            ?.takeIf { it.isNotBlank() }

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_OPEN_SALE_WORKSPACE, true)
            checklistItemId?.let {
                putExtra(MainActivity.EXTRA_FOCUSED_CHECKLIST_ITEM_ID, it)
            }
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            resolvedNotificationId,
            openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val snoozePendingIntent = reminderId?.let {
            SaleReminderScheduler.snoozeReminderIntent(
                context = context,
                reminderId = it,
                notificationId = resolvedNotificationId
            )
        }
        val completePendingIntent = if (
            reminderId != null &&
            !completionActionTitle.isNullOrBlank() &&
            !completionActivityTitle.isNullOrBlank()
        ) {
            SaleReminderScheduler.completeReminderIntent(
                context = context,
                reminderId = reminderId,
                notificationId = resolvedNotificationId,
                activityTitle = completionActivityTitle
            )
        } else {
            null
        }

        val notification = NotificationCompat.Builder(context, SaleReminderScheduler.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setSubText(listingTitle)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_view,
                actionTitle,
                openPendingIntent
            )
            .apply {
                if (completePendingIntent != null && !completionActionTitle.isNullOrBlank()) {
                    addAction(
                        android.R.drawable.checkbox_on_background,
                        completionActionTitle,
                        completePendingIntent
                    )
                }
                if (snoozePendingIntent != null) {
                    addAction(
                        android.R.drawable.ic_lock_idle_alarm,
                        "Snooze 24h",
                        snoozePendingIntent
                    )
                }
            }
            .build()

        NotificationManagerCompat.from(context).notify(resolvedNotificationId, notification)
    }

    private fun showActionFeedbackNotification(
        context: Context,
        notificationId: Int,
        title: String,
        listingTitle: String?,
        body: String,
        checklistItemId: String?
    ) {
        val openPendingIntent = saleWorkspacePendingIntent(
            context = context,
            notificationId = notificationId,
            checklistItemId = checklistItemId
        )
        val notification = NotificationCompat.Builder(context, SaleReminderScheduler.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.checkbox_on_background)
            .setContentTitle(title)
            .setSubText(listingTitle ?: "Private sale workspace")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .setTimeoutAfter(5000)
            .setContentIntent(openPendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    private data class ReminderActionFeedbackCopy(
        val title: String,
        val body: String
    )

    private fun completionFeedbackCopy(
        checklistItemId: String?,
        activityTitle: String,
        offer: SaleOffer,
        currentUser: MarketplaceUserProfile
    ): ReminderActionFeedbackCopy {
        val viewerIsBuyer = currentUser.id == offer.buyerId || (
            currentUser.id != offer.sellerId && currentUser.role == UserRole.BUYER
        )
        val viewerParty = if (viewerIsBuyer) "Buyer" else "Seller"
        val counterpartParty = if (viewerIsBuyer) "Seller" else "Buyer"

        return when (checklistItemId) {
            "buyer-representative" ->
                ReminderActionFeedbackCopy(
                    title = "Buyer legal rep follow-up recorded",
                    body = "Buyer-side legal rep progress is now visible in the deal timeline and secure messages."
                )
            "seller-representative" ->
                ReminderActionFeedbackCopy(
                    title = "Seller legal rep follow-up recorded",
                    body = "Seller-side legal rep progress is now visible in the deal timeline and secure messages."
                )
            "contract-packet" ->
                if (activityTitle.equals("Contract packet follow-up completed", ignoreCase = true)) {
                    ReminderActionFeedbackCopy(
                        title = "Contract packet follow-up recorded",
                        body = "Contract packet progress is now visible in the deal timeline and secure messages."
                    )
                } else {
                    ReminderActionFeedbackCopy(
                        title = "Contract packet issue follow-up recorded",
                        body = "Contract packet progress is now visible in the deal timeline and secure messages."
                    )
                }
            "workspace-invites" ->
                if (activityTitle.equals("Invite sent", ignoreCase = true)) {
                    val inviteParty = reminderInviteFocusParty(
                        offer = offer,
                        currentUser = currentUser
                    )
                    ReminderActionFeedbackCopy(
                        title = "$inviteParty rep invite sent recorded",
                        body = "$inviteParty-side legal invite progress is now visible in the deal timeline and secure messages."
                    )
                } else {
                    val inviteParty = reminderInviteFocusParty(
                        offer = offer,
                        currentUser = currentUser
                    )
                    ReminderActionFeedbackCopy(
                        title = "$inviteParty rep invite follow-up recorded",
                        body = "$inviteParty-side legal invite progress is now visible in the deal timeline and secure messages."
                    )
                }
            "workspace-active" -> {
                val workspaceParty = reminderWorkspaceFocusParty(
                    offer = offer,
                    currentUser = currentUser
                )
                when {
                    activityTitle.equals("Workspace access follow-up completed", ignoreCase = true) ->
                        ReminderActionFeedbackCopy(
                            title = "$workspaceParty rep workspace access follow-up recorded",
                            body = "$workspaceParty-side legal workspace access is now visible in the deal timeline and secure messages."
                        )
                    activityTitle.equals("Workspace receipt follow-up completed", ignoreCase = true) ->
                        ReminderActionFeedbackCopy(
                            title = "$workspaceParty rep receipt follow-up recorded",
                            body = "$workspaceParty-side legal workspace acknowledgement is now visible in the deal timeline and secure messages."
                        )
                    else ->
                        ReminderActionFeedbackCopy(
                            title = "$workspaceParty rep workspace follow-up recorded",
                            body = "$workspaceParty-side legal workspace progress is now visible in the deal timeline and secure messages."
                        )
                }
            }
            "legal-review-pack" ->
                when {
                    activityTitle.equals("Reviewed contract follow-up completed", ignoreCase = true) ->
                        ReminderActionFeedbackCopy(
                            title = "Reviewed contract follow-up recorded",
                            body = "Reviewed contract progress is now visible in the deal timeline and secure messages."
                        )
                    activityTitle.equals("Settlement adjustment follow-up completed", ignoreCase = true) ->
                        ReminderActionFeedbackCopy(
                            title = "Settlement adjustment follow-up recorded",
                            body = "Settlement adjustment progress is now visible in the deal timeline and secure messages."
                        )
                    else ->
                        reminderReviewPackFocus(offer).let { focus ->
                            ReminderActionFeedbackCopy(
                                title = "${focus.title} follow-up recorded",
                                body = "${focus.body} is now visible in the deal timeline and secure messages."
                            )
                        }
                }
            "contract-signatures" -> {
                val packet = offer.contractPacket
                if (activityTitle.equals("Signature confirmed", ignoreCase = true)) {
                    val signingParty = when {
                        packet == null -> viewerParty
                        viewerIsBuyer && packet.buyerSignedAt == null -> "Buyer"
                        !viewerIsBuyer && packet.sellerSignedAt == null -> "Seller"
                        else -> viewerParty
                    }
                    ReminderActionFeedbackCopy(
                        title = "$signingParty signature confirmation recorded",
                        body = "$signingParty signing progress is now visible in the deal timeline and secure messages."
                    )
                } else {
                    val signingParty = when {
                        packet == null -> viewerParty
                        viewerIsBuyer && packet.buyerSignedAt != null && packet.sellerSignedAt == null -> counterpartParty
                        !viewerIsBuyer && packet.sellerSignedAt != null && packet.buyerSignedAt == null -> counterpartParty
                        else -> viewerParty
                    }
                    ReminderActionFeedbackCopy(
                        title = "$signingParty signature follow-up recorded",
                        body = "$signingParty signing progress is now visible in the deal timeline and secure messages."
                    )
                }
            }
            "settlement-statement" ->
                if (activityTitle.equals("Settlement statement follow-up completed", ignoreCase = true)) {
                    ReminderActionFeedbackCopy(
                        title = "Settlement statement follow-up recorded",
                        body = "Settlement statement progress is now visible in the deal timeline and secure messages."
                    )
                } else {
                    ReminderActionFeedbackCopy(
                        title = "Settlement statement upload follow-up recorded",
                        body = "Settlement statement progress is now visible in the deal timeline and secure messages."
                    )
                }
            else ->
                ReminderActionFeedbackCopy(
                    title = "Recorded in sale timeline",
                    body = "$activityTitle. Buyer and seller can now see this update in the deal timeline and secure messages."
                )
        }
    }

    private fun snoozeFeedbackCopy(
        checklistItemId: String?,
        snoozedUntil: Long,
        offer: SaleOffer,
        currentUser: MarketplaceUserProfile
    ): ReminderActionFeedbackCopy {
        val title = when (checklistItemId) {
            "buyer-representative" -> "Buyer legal rep follow-up snoozed"
            "seller-representative" -> "Seller legal rep follow-up snoozed"
            "workspace-invites" -> "${reminderInviteFocusParty(offer, currentUser)} rep invite follow-up snoozed"
            "workspace-active" -> "${reminderWorkspaceFocusParty(offer, currentUser)} rep workspace follow-up snoozed"
            "contract-signatures" -> "${reminderSignatureFocusParty(offer, currentUser)} signature follow-up snoozed"
            "legal-review-pack" -> "${reminderReviewPackFocus(offer).title} follow-up snoozed"
            "settlement-statement" -> "Settlement statement upload follow-up snoozed"
            "contract-packet" -> "Contract packet issue follow-up snoozed"
            else -> "Reminder snoozed"
        }

        return ReminderActionFeedbackCopy(
            title = title,
            body = "Snoozed until ${formatFeedbackTimestamp(snoozedUntil)}. This follow-up remains visible in the deal timeline and secure messages."
        )
    }

    private fun reminderInviteFocusParty(
        offer: SaleOffer,
        currentUser: MarketplaceUserProfile
    ): String {
        val viewerIsBuyer = currentUser.id == offer.buyerId || (
            currentUser.id != offer.sellerId && currentUser.role == UserRole.BUYER
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
            currentUser.id != offer.sellerId && currentUser.role == UserRole.BUYER
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

    private fun reminderReviewPackFocus(
        offer: SaleOffer
    ): ReminderActionFeedbackCopy {
        val hasReviewedContract = offer.documents.any { it.kind == SaleDocumentKind.REVIEWED_CONTRACT_PDF }
        val hasSettlementAdjustment = offer.documents.any { it.kind == SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF }

        return when {
            !hasReviewedContract && hasSettlementAdjustment ->
                ReminderActionFeedbackCopy(
                    title = "Reviewed contract upload",
                    body = "Reviewed contract upload progress"
                )
            hasReviewedContract && !hasSettlementAdjustment ->
                ReminderActionFeedbackCopy(
                    title = "Settlement adjustment upload",
                    body = "Settlement adjustment upload progress"
                )
            else ->
                ReminderActionFeedbackCopy(
                    title = "Legal review pack",
                    body = "Legal review pack progress"
                )
        }
    }

    private fun reminderSignatureFocusParty(
        offer: SaleOffer,
        currentUser: MarketplaceUserProfile
    ): String {
        val viewerIsBuyer = currentUser.id == offer.buyerId || (
            currentUser.id != offer.sellerId && currentUser.role == UserRole.BUYER
        )
        val packet = offer.contractPacket ?: return if (viewerIsBuyer) "Buyer" else "Seller"

        return when {
            viewerIsBuyer && packet.buyerSignedAt != null && packet.sellerSignedAt == null -> "Seller"
            !viewerIsBuyer && packet.sellerSignedAt != null && packet.buyerSignedAt == null -> "Buyer"
            viewerIsBuyer -> "Buyer"
            else -> "Seller"
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

    private fun formatFeedbackTimestamp(timestamp: Long): String {
        return SimpleDateFormat("d MMM, h:mm a", Locale.getDefault()).format(Date(timestamp))
    }

    private fun saleWorkspacePendingIntent(
        context: Context,
        notificationId: Int,
        checklistItemId: String?
    ): PendingIntent {
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_OPEN_SALE_WORKSPACE, true)
            checklistItemId?.let {
                putExtra(MainActivity.EXTRA_FOCUSED_CHECKLIST_ITEM_ID, it)
            }
        }
        return PendingIntent.getActivity(
            context,
            notificationId,
            openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }
}
