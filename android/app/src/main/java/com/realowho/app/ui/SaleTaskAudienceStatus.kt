package com.realowho.app.ui

import android.text.format.DateUtils
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Autorenew
import androidx.compose.material.icons.outlined.RemoveRedEye
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.outlined.WatchLater
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.realowho.app.marketplace.ConversationTaskSnapshotSyncStore
import com.realowho.app.marketplace.SaleTaskAudienceStatus
import com.realowho.app.marketplace.SaleTaskLiveSnapshot
import com.realowho.app.marketplace.SaleTaskLiveSnapshotTone
import com.realowho.app.marketplace.SaleTaskSnapshotAudienceMember

@Composable
internal fun SaleTaskAudienceStatusRow(
    snapshot: SaleTaskLiveSnapshot,
    messageId: String? = null,
    taskId: String? = null,
    audience: List<SaleTaskSnapshotAudienceMember>,
    currentViewerId: String?,
    taskSnapshotStore: ConversationTaskSnapshotSyncStore,
    markAsSeenOnAppear: Boolean = false
) {
    val status = taskSnapshotStore.audienceStatus(
        snapshot = snapshot,
        messageId = messageId,
        taskId = taskId,
        audience = audience
    ) ?: return

    LaunchedEffect(
        snapshot.summary,
        snapshot.tone,
        messageId,
        taskId,
        currentViewerId,
        markAsSeenOnAppear
    ) {
        if (markAsSeenOnAppear && currentViewerId != null) {
            taskSnapshotStore.markUrgentSnapshotSeen(
                snapshot = snapshot,
                messageId = messageId,
                viewerId = currentViewerId,
                taskId = taskId
            )
        }
    }

    val tint = statusTint(status = status, snapshot = snapshot)
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top
    ) {
        Icon(
            imageVector = statusIcon(status),
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(14.dp)
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = primaryLine(status),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = tint
            )
            secondaryLine(status)?.let { line ->
                Text(
                    text = line,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
internal fun SaleTaskAudienceCompactBadge(
    snapshot: SaleTaskLiveSnapshot,
    messageId: String? = null,
    taskId: String? = null,
    audience: List<SaleTaskSnapshotAudienceMember>,
    taskSnapshotStore: ConversationTaskSnapshotSyncStore
) {
    val status = taskSnapshotStore.audienceStatus(
        snapshot = snapshot,
        messageId = messageId,
        taskId = taskId,
        audience = audience
    ) ?: return

    val summary = compactBadgeSummary(
        status = status,
        snapshot = snapshot,
        now = System.currentTimeMillis(),
        neutralTint = MaterialTheme.colorScheme.onSurfaceVariant
    ) ?: return
    Surface(
        color = summary.background,
        shape = MaterialTheme.shapes.extraLarge
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = summary.icon,
                contentDescription = null,
                tint = summary.tint,
                modifier = Modifier.size(12.dp)
            )
            Text(
                text = summary.text,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = summary.tint,
                maxLines = 1
            )
        }
    }
}

private data class CompactBadgeSummary(
    val text: String,
    val icon: ImageVector,
    val tint: Color,
    val background: Color
)

private fun primaryLine(status: SaleTaskAudienceStatus): String {
    return when {
        status.pending.isNotEmpty() && status.seenBy.isEmpty() && status.waitingOn.isEmpty() ->
            "Checking ${status.pending.joinToString()}"
        status.waitingOn.isEmpty() && status.seenBy.isNotEmpty() ->
            "Seen by everyone"
        status.seenBy.isEmpty() ->
            "Not seen yet"
        else ->
            "Seen by ${status.seenBy.joinToString()}"
    }
}

private fun secondaryLine(status: SaleTaskAudienceStatus): String? {
    val details = buildList {
        latestSeenLine(status)?.let(::add)
        if (status.waitingOn.isNotEmpty()) {
            add("Waiting on ${status.waitingOn.joinToString()}")
        }
        if (status.pending.isNotEmpty()) {
            add("Checking ${status.pending.joinToString()}")
        }
    }

    if (details.isEmpty() && status.waitingOn.isEmpty() && status.seenBy.isNotEmpty()) {
        return status.seenBy.joinToString()
    }

    return details.takeIf { it.isNotEmpty() }?.joinToString(" • ")
}

private fun latestSeenLine(status: SaleTaskAudienceStatus): String? {
    val latestSeenEntry = status.seenEntries.firstOrNull() ?: return null
    val relativeTime = DateUtils.getRelativeTimeSpanString(
        latestSeenEntry.seenAt,
        System.currentTimeMillis(),
        DateUtils.MINUTE_IN_MILLIS,
        DateUtils.FORMAT_ABBREV_RELATIVE
    ).toString()
    return "Last seen by ${latestSeenEntry.label} $relativeTime"
}

private fun compactBadgeSummary(
    status: SaleTaskAudienceStatus,
    snapshot: SaleTaskLiveSnapshot,
    now: Long,
    neutralTint: Color
): CompactBadgeSummary? {
    val attentionTint = statusTint(status = status, snapshot = snapshot)
    status.seenEntries.firstOrNull()?.let { latestSeenEntry ->
        val relativeTime = DateUtils.getRelativeTimeSpanString(
            latestSeenEntry.seenAt,
            now,
            DateUtils.MINUTE_IN_MILLIS,
            DateUtils.FORMAT_ABBREV_RELATIVE
        ).toString()
        val tint = if (status.waitingOn.isEmpty()) Color(0xFF18864B) else attentionTint
        return CompactBadgeSummary(
            text = "Seen $relativeTime by ${latestSeenEntry.label}",
            icon = if (status.waitingOn.isEmpty()) Icons.Outlined.RemoveRedEye else Icons.Outlined.WatchLater,
            tint = tint,
            background = tint.copy(alpha = if (status.waitingOn.isEmpty()) 0.14f else 0.12f)
        )
    }

    if (status.waitingOn.isNotEmpty()) {
        return CompactBadgeSummary(
            text = "Waiting on ${status.waitingOn.joinToString()}",
            icon = Icons.Outlined.VisibilityOff,
            tint = attentionTint,
            background = attentionTint.copy(alpha = 0.12f)
        )
    }

    if (status.pending.isNotEmpty()) {
        return CompactBadgeSummary(
            text = "Checking ${status.pending.joinToString()}",
            icon = Icons.Outlined.Autorenew,
            tint = neutralTint,
            background = neutralTint.copy(alpha = 0.10f)
        )
    }

    if (status.seenBy.isNotEmpty()) {
        return CompactBadgeSummary(
            text = "Seen by everyone",
            icon = Icons.Outlined.RemoveRedEye,
            tint = Color(0xFF18864B),
            background = Color(0xFF18864B).copy(alpha = 0.14f)
        )
    }

    return null
}

private fun statusIcon(status: SaleTaskAudienceStatus): ImageVector {
    return when {
        status.pending.isNotEmpty() && status.seenBy.isEmpty() && status.waitingOn.isEmpty() ->
            Icons.Outlined.Autorenew
        status.waitingOn.isEmpty() && status.seenBy.isNotEmpty() ->
            Icons.Outlined.RemoveRedEye
        status.seenBy.isEmpty() ->
            Icons.Outlined.VisibilityOff
        else ->
            Icons.Outlined.WatchLater
    }
}

private fun statusTint(status: SaleTaskAudienceStatus, snapshot: SaleTaskLiveSnapshot): Color {
    return when {
        status.waitingOn.isEmpty() && status.seenBy.isNotEmpty() -> Color(0xFF18864B)
        status.seenBy.isEmpty() || status.waitingOn.isNotEmpty() ->
            if (snapshot.tone == SaleTaskLiveSnapshotTone.CRITICAL) {
                Color(0xFFB86B12)
            } else {
                Color(0xFF0F6B78)
            }
        else -> Color(0xFF0F6B78)
    }
}
