package com.realowho.app.marketplace

import android.content.Context
import android.text.format.DateUtils
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.auth.MarketplaceBackendClient
import com.realowho.app.auth.MarketplaceBackendConfig
import com.realowho.app.auth.MarketplaceRemoteException
import com.realowho.app.auth.MarketplaceRemoteMode
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString

@Serializable
data class ConversationTaskSnapshotViewerState(
    val viewerId: String,
    val seenUrgentSnapshotKeysByMessageId: Map<String, String> = emptyMap(),
    val seenUrgentSnapshotKeysByTaskId: Map<String, String> = emptyMap(),
    val seenUrgentSnapshotSeenAtByMessageId: Map<String, Long> = emptyMap(),
    val seenUrgentSnapshotSeenAtByTaskId: Map<String, Long> = emptyMap()
)

@Serializable
private data class ConversationTaskSnapshotViewerStateEnvelope(
    val state: RemoteConversationTaskSnapshotViewerStatePayload
)

@Serializable
private data class RemoteConversationTaskSnapshotViewerStatePayload(
    @SerialName("viewerID")
    val viewerId: String,
    val seenUrgentSnapshotKeysByMessageID: Map<String, String> = emptyMap(),
    val seenUrgentSnapshotKeysByTaskID: Map<String, String> = emptyMap(),
    val seenUrgentSnapshotSeenAtByMessageID: Map<String, Long> = emptyMap(),
    val seenUrgentSnapshotSeenAtByTaskID: Map<String, Long> = emptyMap()
) {
    fun toAppModel(): ConversationTaskSnapshotViewerState {
        return ConversationTaskSnapshotViewerState(
            viewerId = viewerId,
            seenUrgentSnapshotKeysByMessageId = seenUrgentSnapshotKeysByMessageID,
            seenUrgentSnapshotKeysByTaskId = seenUrgentSnapshotKeysByTaskID,
            seenUrgentSnapshotSeenAtByMessageId = seenUrgentSnapshotSeenAtByMessageID,
            seenUrgentSnapshotSeenAtByTaskId = seenUrgentSnapshotSeenAtByTaskID
        )
    }
}

private fun ConversationTaskSnapshotViewerState.toRemotePayload(): RemoteConversationTaskSnapshotViewerStatePayload {
    return RemoteConversationTaskSnapshotViewerStatePayload(
        viewerId = viewerId,
        seenUrgentSnapshotKeysByMessageID = seenUrgentSnapshotKeysByMessageId,
        seenUrgentSnapshotKeysByTaskID = seenUrgentSnapshotKeysByTaskId,
        seenUrgentSnapshotSeenAtByMessageID = seenUrgentSnapshotSeenAtByMessageId,
        seenUrgentSnapshotSeenAtByTaskID = seenUrgentSnapshotSeenAtByTaskId
    )
}

private interface ConversationTaskSnapshotSyncService {
    suspend fun fetchState(viewerId: String): ConversationTaskSnapshotViewerState
    suspend fun upsertState(state: ConversationTaskSnapshotViewerState): ConversationTaskSnapshotViewerState
}

private class DisabledConversationTaskSnapshotSyncService : ConversationTaskSnapshotSyncService {
    override suspend fun fetchState(viewerId: String): ConversationTaskSnapshotViewerState {
        return ConversationTaskSnapshotViewerState(
            viewerId = viewerId,
            seenUrgentSnapshotKeysByMessageId = emptyMap()
        )
    }

    override suspend fun upsertState(state: ConversationTaskSnapshotViewerState): ConversationTaskSnapshotViewerState {
        return state
    }
}

private class RemoteConversationTaskSnapshotSyncService(
    private val client: MarketplaceBackendClient
) : ConversationTaskSnapshotSyncService {
    override suspend fun fetchState(viewerId: String): ConversationTaskSnapshotViewerState {
        val response: ConversationTaskSnapshotViewerStateEnvelope = client.get(
            path = "v1/task-snapshot-state/$viewerId"
        )
        return response.state.toAppModel()
    }

    override suspend fun upsertState(state: ConversationTaskSnapshotViewerState): ConversationTaskSnapshotViewerState {
        val response: ConversationTaskSnapshotViewerStateEnvelope = client.requestWithBody(
            path = "v1/task-snapshot-state/${state.viewerId}",
            method = "PUT",
            body = ConversationTaskSnapshotViewerStateEnvelope(state = state.toRemotePayload())
        )
        return response.state.toAppModel()
    }
}

private class FallbackConversationTaskSnapshotSyncService(
    private val remote: RemoteConversationTaskSnapshotSyncService,
    private val local: DisabledConversationTaskSnapshotSyncService,
    private val backendConfig: MarketplaceBackendConfig
) : ConversationTaskSnapshotSyncService {
    override suspend fun fetchState(viewerId: String): ConversationTaskSnapshotViewerState {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.fetchState(viewerId)
        }

        return try {
            remote.fetchState(viewerId)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.fetchState(viewerId)
            } else {
                throw error
            }
        }
    }

    override suspend fun upsertState(state: ConversationTaskSnapshotViewerState): ConversationTaskSnapshotViewerState {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.upsertState(state)
        }

        return try {
            remote.upsertState(state)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.upsertState(state)
            } else {
                throw error
            }
        }
    }
}

private object ConversationTaskSnapshotSyncServiceFactory {
    fun create(launchConfiguration: AppLaunchConfiguration): ConversationTaskSnapshotSyncService {
        val backendConfig = MarketplaceBackendConfig.launchDefault(launchConfiguration)
        val local = DisabledConversationTaskSnapshotSyncService()

        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local
        }

        return FallbackConversationTaskSnapshotSyncService(
            remote = RemoteConversationTaskSnapshotSyncService(MarketplaceBackendClient(backendConfig)),
            local = local,
            backendConfig = backendConfig
        )
    }
}

class ConversationTaskSnapshotSyncStore(
    context: Context,
    launchConfiguration: AppLaunchConfiguration
) {
    private val syncService = ConversationTaskSnapshotSyncServiceFactory.create(launchConfiguration)
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
    }
    private val storageFile = File(
        File(context.filesDir, "real-o-who-marketplace"),
        "conversation-task-snapshot-state.json"
    )
    private val isEphemeral = launchConfiguration.isScreenshotMode
    private val remoteSyncEnabled =
        MarketplaceBackendConfig.launchDefault(launchConfiguration).mode == MarketplaceRemoteMode.REMOTE_PREFERRED
    private val syncScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var statesByViewerId by mutableStateOf<Map<String, ConversationTaskSnapshotViewerState>>(emptyMap())
    private var loadedViewerIds by mutableStateOf<Set<String>>(emptySet())

    init {
        if (!isEphemeral) {
            load()
        }
    }

    companion object {
        fun viewerIdForUser(userId: String): String = "user:$userId"

        fun viewerIdForInvite(inviteId: String): String = "invite:$inviteId"
    }

    suspend fun refresh(viewerId: String?) {
        val normalizedViewerId = viewerId?.trim()?.takeIf { it.isNotEmpty() } ?: return

        if (statesByViewerId.containsKey(normalizedViewerId)) {
            loadedViewerIds = loadedViewerIds + normalizedViewerId
        }

        if (!remoteSyncEnabled) {
            loadedViewerIds = loadedViewerIds + normalizedViewerId
            return
        }

        runCatching {
            syncService.fetchState(normalizedViewerId)
        }.onSuccess { remoteState ->
            statesByViewerId = statesByViewerId + (normalizedViewerId to remoteState)
            loadedViewerIds = loadedViewerIds + normalizedViewerId
            persist()
        }.onFailure {
            loadedViewerIds = loadedViewerIds + normalizedViewerId
        }
    }

    suspend fun refresh(viewerIds: Collection<String>) {
        val normalizedViewerIds = viewerIds
            .mapNotNull { it.trim().takeIf(String::isNotEmpty) }
            .toSet()
            .sorted()

        normalizedViewerIds.forEach { viewerId ->
            refresh(viewerId)
        }
    }

    fun shouldEmphasizeUrgentSnapshot(
        snapshot: SaleTaskLiveSnapshot?,
        messageId: String,
        viewerId: String?,
        taskId: String? = null
    ): Boolean {
        val normalizedViewerId = viewerId?.trim()?.takeIf { it.isNotEmpty() } ?: return false
        val currentSnapshot = snapshot ?: return false
        if (!currentSnapshot.needsUrgentViewerAttention() || normalizedViewerId !in loadedViewerIds) {
            return false
        }

        val snapshotKey = currentSnapshot.viewerSnapshotKey()
        val state = statesByViewerId[normalizedViewerId]
        val normalizedTaskId = taskId?.trim()?.takeIf(String::isNotEmpty)
        if (normalizedTaskId != null && state?.seenUrgentSnapshotKeysByTaskId?.get(normalizedTaskId) == snapshotKey) {
            return false
        }

        return state?.seenUrgentSnapshotKeysByMessageId?.get(messageId) != snapshotKey
    }

    fun markUrgentSnapshotSeen(
        snapshot: SaleTaskLiveSnapshot?,
        messageId: String? = null,
        viewerId: String?,
        taskId: String? = null
    ) {
        val normalizedViewerId = viewerId?.trim()?.takeIf { it.isNotEmpty() } ?: return
        val currentSnapshot = snapshot ?: return
        if (!currentSnapshot.needsUrgentViewerAttention()) {
            return
        }

        val snapshotKey = currentSnapshot.viewerSnapshotKey()
        val normalizedMessageId = messageId?.trim()?.takeIf(String::isNotEmpty)
        val normalizedTaskId = taskId?.trim()?.takeIf(String::isNotEmpty)
        val seenAt = System.currentTimeMillis()
        val currentState = statesByViewerId[normalizedViewerId]
            ?: ConversationTaskSnapshotViewerState(
                viewerId = normalizedViewerId,
                seenUrgentSnapshotKeysByMessageId = emptyMap(),
                seenUrgentSnapshotKeysByTaskId = emptyMap(),
                seenUrgentSnapshotSeenAtByMessageId = emptyMap(),
                seenUrgentSnapshotSeenAtByTaskId = emptyMap()
            )

        val hasSeenMessageSnapshot = normalizedMessageId?.let {
            currentState.seenUrgentSnapshotKeysByMessageId[it] == snapshotKey
        } ?: true
        val hasSeenTaskSnapshot = normalizedTaskId?.let {
            currentState.seenUrgentSnapshotKeysByTaskId[it] == snapshotKey
        } ?: true

        if (hasSeenMessageSnapshot && hasSeenTaskSnapshot) {
            loadedViewerIds = loadedViewerIds + normalizedViewerId
            return
        }

        val updatedState = currentState.copy(
            seenUrgentSnapshotKeysByMessageId =
                if (normalizedMessageId != null) {
                    currentState.seenUrgentSnapshotKeysByMessageId + (normalizedMessageId to snapshotKey)
                } else {
                    currentState.seenUrgentSnapshotKeysByMessageId
                },
            seenUrgentSnapshotKeysByTaskId =
                if (normalizedTaskId != null) {
                    currentState.seenUrgentSnapshotKeysByTaskId + (normalizedTaskId to snapshotKey)
                } else {
                    currentState.seenUrgentSnapshotKeysByTaskId
                },
            seenUrgentSnapshotSeenAtByMessageId =
                if (normalizedMessageId != null) {
                    currentState.seenUrgentSnapshotSeenAtByMessageId + (normalizedMessageId to seenAt)
                } else {
                    currentState.seenUrgentSnapshotSeenAtByMessageId
                },
            seenUrgentSnapshotSeenAtByTaskId =
                if (normalizedTaskId != null) {
                    currentState.seenUrgentSnapshotSeenAtByTaskId + (normalizedTaskId to seenAt)
                } else {
                    currentState.seenUrgentSnapshotSeenAtByTaskId
                }
        )
        statesByViewerId = statesByViewerId + (normalizedViewerId to updatedState)
        loadedViewerIds = loadedViewerIds + normalizedViewerId
        persist()

        if (isEphemeral || !remoteSyncEnabled) {
            return
        }

        syncScope.launch {
            runCatching {
                syncService.upsertState(updatedState)
            }.onSuccess { syncedState ->
                statesByViewerId = statesByViewerId + (normalizedViewerId to syncedState)
                loadedViewerIds = loadedViewerIds + normalizedViewerId
                persist()
            }
        }
    }

    fun audienceStatus(
        snapshot: SaleTaskLiveSnapshot?,
        messageId: String? = null,
        taskId: String? = null,
        audience: List<SaleTaskSnapshotAudienceMember>
    ): SaleTaskAudienceStatus? {
        val currentSnapshot = snapshot ?: return null
        if (!currentSnapshot.needsUrgentViewerAttention() || audience.isEmpty()) {
            return null
        }

        val snapshotKey = currentSnapshot.viewerSnapshotKey()
        val normalizedMessageId = messageId?.trim()?.takeIf(String::isNotEmpty)
        val normalizedTaskId = taskId?.trim()?.takeIf(String::isNotEmpty)
        val seenBy = mutableListOf<String>()
        val waitingOn = mutableListOf<String>()
        val pending = mutableListOf<String>()
        val seenEntries = mutableListOf<SaleTaskAudienceSeenEntry>()

        audience.forEach { member ->
            val normalizedViewerId = member.viewerId.trim().takeIf(String::isNotEmpty) ?: return@forEach
            if (normalizedViewerId !in loadedViewerIds) {
                pending += member.label
                return@forEach
            }

            val state = statesByViewerId[normalizedViewerId]
            val hasSeenTask = normalizedTaskId?.let {
                state?.seenUrgentSnapshotKeysByTaskId?.get(it) == snapshotKey
            } ?: false
            val hasSeenMessage = normalizedMessageId?.let {
                state?.seenUrgentSnapshotKeysByMessageId?.get(it) == snapshotKey
            } ?: false
            val seenAt = normalizedTaskId?.let {
                state?.seenUrgentSnapshotSeenAtByTaskId?.get(it)
            } ?: normalizedMessageId?.let {
                state?.seenUrgentSnapshotSeenAtByMessageId?.get(it)
            }

            if (hasSeenTask || hasSeenMessage) {
                seenBy += member.label
                if (seenAt != null) {
                    seenEntries += SaleTaskAudienceSeenEntry(
                        label = member.label,
                        seenAt = seenAt
                    )
                }
            } else {
                waitingOn += member.label
            }
        }

        if (seenBy.isEmpty() && waitingOn.isEmpty() && pending.isEmpty()) {
            return null
        }

        return SaleTaskAudienceStatus(
            seenBy = seenBy,
            waitingOn = waitingOn,
            pending = pending,
            seenEntries = seenEntries.sortedByDescending { it.seenAt }
        )
    }

    fun reminderNotificationContext(
        snapshot: SaleTaskLiveSnapshot?,
        taskId: String?,
        audience: List<SaleTaskSnapshotAudienceMember>,
        now: Long = System.currentTimeMillis()
    ): String? {
        val status = audienceStatus(
            snapshot = snapshot,
            messageId = null,
            taskId = taskId,
            audience = audience
        ) ?: return null

        status.seenEntries.firstOrNull()?.let { latestSeenEntry ->
            val relativeTime = DateUtils.getRelativeTimeSpanString(
                latestSeenEntry.seenAt,
                now,
                DateUtils.MINUTE_IN_MILLIS,
                DateUtils.FORMAT_ABBREV_RELATIVE
            ).toString()
            return if (status.waitingOn.isEmpty()) {
                "Seen $relativeTime by ${latestSeenEntry.label}."
            } else {
                "Seen $relativeTime by ${latestSeenEntry.label}. Waiting on ${status.waitingOn.joinToString()}."
            }
        }

        if (status.waitingOn.isNotEmpty()) {
            return "Waiting on ${status.waitingOn.joinToString()}."
        }

        if (status.pending.isNotEmpty()) {
            return "Checking ${status.pending.joinToString()}."
        }

        if (status.seenBy.isNotEmpty()) {
            return "Seen by everyone."
        }

        return null
    }

    fun notificationFingerprint(viewerIds: Collection<String>): String {
        return viewerIds
            .mapNotNull { it.trim().takeIf(String::isNotEmpty) }
            .toSet()
            .sorted()
            .joinToString("|") { viewerId ->
                val loadedMarker = if (viewerId in loadedViewerIds) "loaded" else "pending"
                val state = statesByViewerId[viewerId]
                val messageKeys = state?.seenUrgentSnapshotKeysByMessageId
                    ?.toSortedMap()
                    ?.entries
                    ?.joinToString(",") { "${it.key}=${it.value}" }
                    .orEmpty()
                val taskKeys = state?.seenUrgentSnapshotKeysByTaskId
                    ?.toSortedMap()
                    ?.entries
                    ?.joinToString(",") { "${it.key}=${it.value}" }
                    .orEmpty()
                val messageTimes = state?.seenUrgentSnapshotSeenAtByMessageId
                    ?.toSortedMap()
                    ?.entries
                    ?.joinToString(",") { "${it.key}=${it.value}" }
                    .orEmpty()
                val taskTimes = state?.seenUrgentSnapshotSeenAtByTaskId
                    ?.toSortedMap()
                    ?.entries
                    ?.joinToString(",") { "${it.key}=${it.value}" }
                    .orEmpty()

                listOf(
                    viewerId,
                    loadedMarker,
                    messageKeys,
                    taskKeys,
                    messageTimes,
                    taskTimes
                ).joinToString("~")
            }
    }

    private fun load() {
        runCatching {
            if (!storageFile.exists()) {
                return
            }

            val snapshot = json.decodeFromString<Map<String, ConversationTaskSnapshotViewerState>>(storageFile.readText())
            statesByViewerId = snapshot
            loadedViewerIds = snapshot.keys
        }
    }

    private fun persist() {
        if (isEphemeral) {
            return
        }

        runCatching {
            storageFile.parentFile?.mkdirs()
            storageFile.writeText(json.encodeToString(statesByViewerId))
        }
    }
}

private fun SaleTaskLiveSnapshot.viewerSnapshotKey(): String {
    return "${tone.name}|$summary"
}

private fun SaleTaskLiveSnapshot.needsUrgentViewerAttention(): Boolean {
    val normalizedSummary = summary.lowercase()
    return tone == SaleTaskLiveSnapshotTone.CRITICAL ||
        normalizedSummary.contains("overdue") ||
        normalizedSummary.contains("follow-up") ||
        normalizedSummary.contains("follow up")
}
