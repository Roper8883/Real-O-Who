package com.realowho.app.ui

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.realowho.app.auth.MarketplaceUserProfile
import com.realowho.app.auth.UserRole
import com.realowho.app.marketplace.ConversationSaleTaskTarget
import com.realowho.app.marketplace.ConversationTaskSnapshotSyncStore
import com.realowho.app.marketplace.ConversationStore
import com.realowho.app.marketplace.LegalInviteRole
import com.realowho.app.marketplace.SaleCoordinationStore
import com.realowho.app.marketplace.SaleChecklistItem
import com.realowho.app.marketplace.SaleChecklistStatus
import com.realowho.app.marketplace.SaleDocument
import com.realowho.app.marketplace.SaleDocumentKind
import com.realowho.app.marketplace.SaleDocumentRenderer
import com.realowho.app.marketplace.SaleTaskLiveSnapshot
import com.realowho.app.marketplace.SaleTaskSnapshotAudienceMember
import com.realowho.app.marketplace.SaleUpdateKind
import com.realowho.app.marketplace.SaleUpdateMessage
import com.realowho.app.marketplace.isDueSoon
import com.realowho.app.marketplace.isExpired
import com.realowho.app.marketplace.isOverdue
import com.realowho.app.marketplace.isRevoked
import com.realowho.app.marketplace.isUnavailable
import com.realowho.app.marketplace.nextActionSummary
import com.realowho.app.marketplace.ownerSummary
import com.realowho.app.marketplace.reminderSummary
import com.realowho.app.marketplace.settlementChecklist
import com.realowho.app.marketplace.taskSnapshotAudienceMembers
import com.realowho.app.marketplace.taskSnapshotId
import com.realowho.app.marketplace.liveTaskSnapshot
import com.realowho.app.marketplace.targetSummary
import kotlinx.coroutines.launch
import java.io.File
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun LegalWorkspaceScreen(
    saleStore: SaleCoordinationStore,
    conversationStore: ConversationStore,
    taskSnapshotStore: ConversationTaskSnapshotSyncStore
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val session = saleStore.legalWorkspaceSession
    val invite = saleStore.currentLegalWorkspaceInvite()
    val listing = saleStore.listing
    val offer = saleStore.offer
    var noticeMessage by androidx.compose.runtime.remember { mutableStateOf<String?>(null) }
    var pendingUploadKind by androidx.compose.runtime.remember { mutableStateOf<SaleDocumentKind?>(null) }

    if (session == null || invite == null) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFFF7FBFF))
                .padding(20.dp)
        ) {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(
                    modifier = Modifier.padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text("Legal workspace unavailable", fontWeight = FontWeight.SemiBold)
                    Text(
                        "Return to the start screen and reopen the sale with the invite code.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Button(onClick = { saleStore.closeLegalWorkspace() }) {
                        Text("Return to Start")
                    }
                }
            }
        }
        return
    }

    val buyer = legalWorkspaceParty(
        id = offer.buyerId,
        role = UserRole.BUYER,
        suburb = listing.address.suburb
    )
    val seller = legalWorkspaceParty(
        id = offer.sellerId,
        role = UserRole.SELLER,
        suburb = listing.address.suburb
    )
    val sender = if (invite.role == LegalInviteRole.BUYER_REPRESENTATIVE) buyer else seller
    val recipient = if (sender.id == buyer.id) seller else buyer
    val pdfPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        val kind = pendingUploadKind
        pendingUploadKind = null
        if (uri == null || kind == null) {
            return@rememberLauncherForActivityResult
        }

        coroutineScope.launch {
            runCatching {
                val fileName = legalFileName(context, uri, kind)
                val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: error("Could not read the selected PDF.")
                val outcome = saleStore.uploadLegalWorkspaceDocument(
                    kind = kind,
                    fileName = fileName,
                    bytes = bytes,
                    mimeType = "application/pdf"
                ) ?: error("Could not attach that PDF right now.")
                saleStore.syncToBackend()
                conversationStore.activateSession(sender, recipient, listing)
                conversationStore.sendMessage(
                    listing = listing,
                    sender = sender,
                    recipient = recipient,
                    body = outcome.threadMessage,
                    isSystem = true,
                    saleTaskTarget = ConversationSaleTaskTarget(
                        listingId = listing.id,
                        offerId = offer.id,
                        checklistItemId = outcome.checklistItemId
                    )
                )
                outcome.noticeMessage
            }.onSuccess { message ->
                noticeMessage = message
            }.onFailure { error ->
                noticeMessage = error.message ?: "Could not attach that PDF right now."
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color(0xFFE8F6FF), Color(0xFFF7FBFF))
                )
            )
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                WorkspaceHeroCard(
                    title = invite.professionalName,
                    subtitle = invite.role.title,
                    body = "${listing.address.fullLine}\nInvite code ${session.inviteCode}"
                )
            }

            item {
                WorkspaceSummaryCard(
                    title = "Sale summary",
                    body = listing.summary
                ) {
                    WorkspaceMetric(label = "Offer", value = legalFormatAmount(offer.amount))
                    WorkspaceMetric(label = "Status", value = offer.status.title)
                    WorkspaceMetric(label = "Conditions", value = offer.conditions)
                }
            }

            item {
                WorkspaceSummaryCard(
                    title = "Workspace status",
                    body = "Invite created ${legalFormatTimestamp(invite.createdAt)} by ${invite.generatedByName}."
                ) {
                    invite.activatedAt?.let {
                        Text(
                            text = "First opened ${legalFormatTimestamp(it)}",
                            fontWeight = FontWeight.SemiBold,
                            color = Color(0xFF0B6B7A)
                        )
                    }
                    invite.revokedAt?.let {
                        Text(
                            text = "Invite revoked ${legalFormatTimestamp(it)}",
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                    Text(
                        text = invite.acknowledgedAt?.let { "Acknowledged ${legalFormatTimestamp(it)}" }
                            ?: "Waiting for acknowledgement",
                        fontWeight = FontWeight.SemiBold,
                        color = if (invite.acknowledgedAt != null) Color(0xFF0B6B7A) else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = if (invite.isRevoked) {
                            "Invite access has been revoked. Request a fresh invite from the buyer or seller."
                        } else if (invite.isExpired) {
                            "Invite expired ${legalFormatTimestamp(invite.expiresAt)}. Request a fresh invite from the buyer or seller."
                        } else {
                            "Invite valid until ${legalFormatTimestamp(invite.expiresAt)}."
                        },
                        color = if (invite.isUnavailable) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            item {
                WorkspaceSummaryCard(
                    title = "Settlement checklist",
                    body = "The buyer, seller, and both legal reps can all work from the same live milestone list."
                ) {
                    SettlementChecklistContent(items = offer.settlementChecklist)
                }
            }

            item {
                WorkspaceSummaryCard(
                    title = "Legal actions",
                    body = "Acknowledge the handoff, then upload the reviewed contract or settlement adjustments back into the shared sale workspace."
                ) {
                    Button(
                        onClick = {
                            coroutineScope.launch {
                                val outcome = saleStore.acknowledgeLegalWorkspaceInvite() ?: return@launch
                                saleStore.syncToBackend()
                                conversationStore.activateSession(sender, recipient, listing)
                                conversationStore.sendMessage(
                                    listing = listing,
                                    sender = sender,
                                    recipient = recipient,
                                    body = outcome.threadMessage,
                                    isSystem = true,
                                    saleTaskTarget = ConversationSaleTaskTarget(
                                        listingId = listing.id,
                                        offerId = offer.id,
                                        checklistItemId = outcome.checklistItemId
                                    )
                                )
                                noticeMessage = outcome.noticeMessage
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = invite.acknowledgedAt == null && !invite.isUnavailable
                    ) {
                        Text(if (invite.acknowledgedAt == null) "Acknowledge Receipt" else "Receipt Recorded")
                    }

                    OutlinedButton(
                        onClick = {
                            pendingUploadKind = SaleDocumentKind.REVIEWED_CONTRACT_PDF
                            pdfPicker.launch(arrayOf("application/pdf"))
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !invite.isUnavailable
                    ) {
                        Text("Attach Reviewed Contract PDF")
                    }

                    OutlinedButton(
                        onClick = {
                            pendingUploadKind = SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF
                            pdfPicker.launch(arrayOf("application/pdf"))
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !invite.isUnavailable
                    ) {
                        Text("Attach Settlement Adjustment PDF")
                    }
                }
            }

            item {
                WorkspaceSummaryCard(
                    title = "Shared sale documents",
                    body = "Contract, rates, ID, and legal review PDFs stay attached to the sale so every party works from the latest version."
                ) {
                    offer.documents.sortedByDescending { it.createdAt }.forEach { document ->
                        LegalWorkspaceDocumentCard(
                            document = document,
                            onShareDocument = {
                                runCatching {
                                    val file = SaleDocumentRenderer.render(
                                        context = context,
                                        document = document,
                                        listing = listing,
                                        offer = offer,
                                        buyer = buyer,
                                        seller = seller
                                    )
                                    legalShareSaleDocument(context, file, document.kind.title)
                                }.onSuccess {
                                    noticeMessage = "${document.kind.title} is ready to share."
                                }.onFailure { error ->
                                    noticeMessage = error.message ?: "Could not prepare the PDF right now."
                                }
                            }
                        )
                    }
                }
            }

            item {
                WorkspaceSummaryCard(
                    title = "Sale timeline",
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
                                SaleTimelineBadge(
                                    update = update,
                                    snapshot = liveSnapshot,
                                    taskId = checklistItemId?.let(offer::taskSnapshotId),
                                    audience = offer.taskSnapshotAudienceMembers,
                                    taskSnapshotStore = taskSnapshotStore
                                )
                                Text(update.title, fontWeight = FontWeight.SemiBold)
                                Text(update.body, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                if (checklistItemId != null && liveSnapshot != null) {
                                    SaleTaskAudienceStatusRow(
                                        snapshot = liveSnapshot,
                                        taskId = offer.taskSnapshotId(checklistItemId),
                                        audience = offer.taskSnapshotAudienceMembers,
                                        currentViewerId = ConversationTaskSnapshotSyncStore.viewerIdForInvite(session.inviteId),
                                        taskSnapshotStore = taskSnapshotStore,
                                        markAsSeenOnAppear = true
                                    )
                                }
                                Text(
                                    legalFormatTimestamp(update.createdAt),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            item {
                OutlinedButton(
                    onClick = { saleStore.closeLegalWorkspace() },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Exit Legal Workspace")
                }
            }

            if (noticeMessage != null) {
                item {
                    WorkspaceNoticeCard(noticeMessage.orEmpty())
                }
            }
        }
    }
}

@Composable
private fun LegalWorkspaceDocumentCard(
    document: SaleDocument,
    onShareDocument: () -> Unit
) {
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
                text = "${document.fileName} • Added ${legalFormatTimestamp(document.createdAt)} by ${document.uploadedByName}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            OutlinedButton(onClick = onShareDocument) {
                Text("Share PDF")
            }
        }
    }
}

@Composable
private fun WorkspaceMetric(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(text = label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = value, fontWeight = FontWeight.SemiBold)
    }
}

private fun legalWorkspaceParty(
    id: String,
    role: UserRole,
    suburb: String
): MarketplaceUserProfile {
    return MarketplaceUserProfile(
        id = id,
        name = if (role == UserRole.BUYER) "Buyer" else "Seller",
        role = role,
        suburb = suburb,
        headline = "Invite-only legal workspace",
        verificationNote = "Legal workspace",
        createdAt = System.currentTimeMillis()
    )
}

private fun legalFileName(
    context: android.content.Context,
    uri: Uri,
    kind: SaleDocumentKind
): String {
    val name = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                cursor.getString(index)
            } else {
                null
            }
        }

    return when {
        !name.isNullOrBlank() -> name
        kind == SaleDocumentKind.REVIEWED_CONTRACT_PDF -> "reviewed-contract.pdf"
        kind == SaleDocumentKind.SETTLEMENT_ADJUSTMENT_PDF -> "settlement-adjustment.pdf"
        else -> "legal-workspace-document.pdf"
    }
}

@Composable
private fun WorkspaceHeroCard(title: String, subtitle: String, body: String) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color.Transparent)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        colors = listOf(Color(0xFF0B384D), Color(0xFF189399), Color(0xFF63D0EF))
                    )
                )
                .padding(22.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(title, color = Color.White, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Text(subtitle, color = Color.White.copy(alpha = 0.9f), fontWeight = FontWeight.SemiBold)
            Text(body, color = Color.White.copy(alpha = 0.86f))
        }
    }
}

@Composable
private fun WorkspaceSummaryCard(
    title: String,
    body: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(body, color = MaterialTheme.colorScheme.onSurfaceVariant)
            content()
        }
    }
}

@Composable
private fun WorkspaceNoticeCard(message: String) {
    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFE7F5F5))) {
        Text(
            text = message,
            modifier = Modifier.padding(18.dp),
            color = Color(0xFF084C54),
            style = MaterialTheme.typography.bodyMedium
        )
    }
}

private fun legalShareSaleDocument(context: android.content.Context, file: File, title: String) {
    val documentUri = FileProvider.getUriForFile(
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

private fun legalFormatAmount(amount: Int): String {
    return NumberFormat.getCurrencyInstance(Locale("en", "AU")).format(amount)
}

private fun legalFormatTimestamp(timestamp: Long): String {
    val formatter = SimpleDateFormat("d MMM yyyy, h:mm a", Locale.getDefault())
    return formatter.format(Date(timestamp))
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SettlementChecklistContent(
    items: List<SaleChecklistItem>,
    focusedChecklistItemId: String? = null
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items.forEach { item ->
            SettlementChecklistRow(
                item = item,
                isFocused = item.id == focusedChecklistItemId
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SettlementChecklistRow(
    item: SaleChecklistItem,
    isFocused: Boolean = false
) {
    val bringIntoViewRequester = remember { BringIntoViewRequester() }
    var didBringIntoView by remember(item.id) { mutableStateOf(false) }

    LaunchedEffect(isFocused) {
        if (isFocused && !didBringIntoView) {
            bringIntoViewRequester.bringIntoView()
            didBringIntoView = true
        }
    }

    Surface(
        color = if (isFocused) Color(0xFFFFF2DB) else Color(0xFFF9FBFC),
        shape = MaterialTheme.shapes.large,
        modifier = Modifier
            .fillMaxWidth()
            .bringIntoViewRequester(bringIntoViewRequester)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = item.title,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f)
                )
                Surface(
                    color = checklistStatusBackground(item.status),
                    shape = MaterialTheme.shapes.small
                ) {
                    Text(
                        text = item.status.title,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        color = checklistStatusTint(item.status),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            Text(
                text = item.detail,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = item.ownerSummary,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall
            )
            item.targetSummary?.let {
                Text(
                    text = it,
                    color = checklistAttentionTint(item),
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold
                )
            }
            item.nextActionSummary?.let {
                Text(
                    text = it,
                    color = checklistStatusTint(item.status),
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold
                )
            }
            item.reminderSummary?.let {
                Text(
                    text = it,
                    color = checklistAttentionTint(item),
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold
                )
            }
            item.supporting?.let {
                Text(
                    text = it,
                    color = checklistStatusTint(item.status),
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@Composable
private fun SaleTimelineBadge(
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

private fun checklistStatusTint(status: SaleChecklistStatus): Color {
    return when (status) {
        SaleChecklistStatus.PENDING -> Color(0xFF616B75)
        SaleChecklistStatus.IN_PROGRESS -> Color(0xFFB86B12)
        SaleChecklistStatus.COMPLETED -> Color(0xFF0B6B7A)
    }
}

private fun checklistStatusBackground(status: SaleChecklistStatus): Color {
    return when (status) {
        SaleChecklistStatus.PENDING -> Color(0xFFECEFF2)
        SaleChecklistStatus.IN_PROGRESS -> Color(0xFFFFF1D8)
        SaleChecklistStatus.COMPLETED -> Color(0xFFE0F6F1)
    }
}

@Composable
private fun checklistAttentionTint(item: SaleChecklistItem): Color {
    return when {
        item.isOverdue -> MaterialTheme.colorScheme.error
        item.isDueSoon || item.reminderSummary != null -> Color(0xFFB86B12)
        else -> checklistStatusTint(item.status)
    }
}
