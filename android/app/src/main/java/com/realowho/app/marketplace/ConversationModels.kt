package com.realowho.app.marketplace

import kotlinx.serialization.Serializable

@Serializable
data class ConversationSaleTaskTarget(
    val listingId: String,
    val offerId: String,
    val checklistItemId: String
)

@Serializable
data class ConversationMessage(
    val id: String,
    val senderId: String,
    val sentAt: Long,
    val body: String,
    val isSystem: Boolean,
    val saleTaskTarget: ConversationSaleTaskTarget? = null
)

@Serializable
data class ConversationThread(
    val id: String,
    val listingId: String,
    val participantIds: List<String>,
    val encryptionLabel: String,
    val updatedAt: Long,
    val messages: List<ConversationMessage>
)

@Serializable
data class ConversationSnapshot(
    val conversations: List<ConversationThread>
)
