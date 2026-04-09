package com.realowho.app.marketplace

import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.auth.MarketplaceBackendClient
import com.realowho.app.auth.MarketplaceBackendConfig
import com.realowho.app.auth.MarketplaceRemoteMode
import java.time.Instant
import kotlinx.serialization.Serializable

interface ConversationSyncService {
    suspend fun fetchThreads(userId: String): List<ConversationThread>
    suspend fun upsertConversation(thread: ConversationThread): ConversationThread
}

object ConversationSyncServiceFactory {
    fun create(
        launchConfiguration: AppLaunchConfiguration,
        backendConfig: MarketplaceBackendConfig = MarketplaceBackendConfig.launchDefault(launchConfiguration)
    ): ConversationSyncService {
        return if (backendConfig.mode == MarketplaceRemoteMode.REMOTE_PREFERRED) {
            RemoteConversationSyncService(MarketplaceBackendClient(backendConfig))
        } else {
            DisabledConversationSyncService
        }
    }
}

object DisabledConversationSyncService : ConversationSyncService {
    override suspend fun fetchThreads(userId: String): List<ConversationThread> = emptyList()

    override suspend fun upsertConversation(thread: ConversationThread): ConversationThread = thread
}

private class RemoteConversationSyncService(
    private val client: MarketplaceBackendClient
) : ConversationSyncService {
    override suspend fun fetchThreads(userId: String): List<ConversationThread> {
        val response = client.get<RemoteConversationListEnvelope>(
            path = "v1/conversations",
            queryParameters = mapOf("userId" to userId)
        )
        return response.conversations.map { it.toAppModel() }
    }

    override suspend fun upsertConversation(thread: ConversationThread): ConversationThread {
        val response = client.requestWithBody<RemoteConversationPayload, RemoteConversationEnvelope>(
            path = "v1/conversations/${thread.id}",
            method = "PUT",
            body = thread.toRemotePayload()
        )
        return response.conversation.toAppModel()
    }
}

@Serializable
private data class RemoteConversationEnvelope(
    val conversation: RemoteConversationPayload
)

@Serializable
private data class RemoteConversationListEnvelope(
    val conversations: List<RemoteConversationPayload>
)

@Serializable
private data class RemoteConversationPayload(
    val id: String,
    val listingId: String,
    val participantIds: List<String>,
    val encryptionLabel: String,
    val updatedAt: String,
    val messages: List<RemoteConversationMessagePayload>
) {
    fun toAppModel(): ConversationThread {
        return ConversationThread(
            id = id,
            listingId = listingId,
            participantIds = participantIds,
            encryptionLabel = encryptionLabel,
            updatedAt = updatedAt.toEpochMillis(),
            messages = messages.map { it.toAppModel() }
        )
    }
}

@Serializable
private data class RemoteConversationMessagePayload(
    val id: String,
    val senderId: String,
    val sentAt: String,
    val body: String,
    val isSystem: Boolean,
    val saleTaskTarget: ConversationSaleTaskTarget? = null
) {
    fun toAppModel(): ConversationMessage {
        return ConversationMessage(
            id = id,
            senderId = senderId,
            sentAt = sentAt.toEpochMillis(),
            body = body,
            isSystem = isSystem,
            saleTaskTarget = saleTaskTarget
        )
    }
}

private fun ConversationThread.toRemotePayload(): RemoteConversationPayload {
    return RemoteConversationPayload(
        id = id,
        listingId = listingId,
        participantIds = participantIds,
        encryptionLabel = encryptionLabel,
        updatedAt = Instant.ofEpochMilli(updatedAt).toString(),
        messages = messages.map { message ->
            RemoteConversationMessagePayload(
                id = message.id,
                senderId = message.senderId,
                sentAt = Instant.ofEpochMilli(message.sentAt).toString(),
                body = message.body,
                isSystem = message.isSystem,
                saleTaskTarget = message.saleTaskTarget
            )
        }
    )
}

private fun String.toEpochMillis(): Long {
    return runCatching { Instant.parse(this).toEpochMilli() }
        .getOrElse { System.currentTimeMillis() }
}
