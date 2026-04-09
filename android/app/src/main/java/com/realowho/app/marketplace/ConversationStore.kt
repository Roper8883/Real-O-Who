package com.realowho.app.marketplace

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.auth.MarketplaceUserProfile
import com.realowho.app.auth.UserRole
import java.io.File
import java.nio.ByteBuffer
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class ConversationStore(
    context: Context,
    launchConfiguration: AppLaunchConfiguration,
    private val syncService: ConversationSyncService = ConversationSyncServiceFactory.create(
        launchConfiguration
    )
) {
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
    }
    private val storageFile = File(
        File(context.filesDir, "real-o-who-marketplace"),
        "conversations.bin"
    )
    private val isEphemeral = launchConfiguration.isScreenshotMode
    private val vault = ConversationVault()

    var conversations by mutableStateOf(listOf<ConversationThread>())
        private set

    init {
        if (!isEphemeral) {
            load()
        }
    }

    suspend fun activateSession(
        user: MarketplaceUserProfile,
        counterpart: MarketplaceUserProfile,
        listing: SaleListing
    ) {
        if (!isEphemeral) {
            runCatching {
                syncService.fetchThreads(user.id)
            }.onSuccess { remoteThreads ->
                mergeRemoteThreads(remoteThreads)
            }
        }

        val buyer = if (user.role == UserRole.BUYER) user else counterpart
        val seller = if (user.role == UserRole.SELLER) user else counterpart
        ensureConversation(listing, buyer, seller)
    }

    fun threadFor(
        listingId: String,
        currentUserId: String,
        counterpartId: String
    ): ConversationThread? {
        return conversations
            .filter { thread ->
                thread.listingId == listingId &&
                    thread.participantIds.toSet() == setOf(currentUserId, counterpartId)
            }
            .maxByOrNull { it.updatedAt }
    }

    suspend fun sendMessage(
        listing: SaleListing,
        sender: MarketplaceUserProfile,
        recipient: MarketplaceUserProfile,
        body: String,
        isSystem: Boolean = false,
        saleTaskTarget: ConversationSaleTaskTarget? = null
    ): ConversationThread? {
        val trimmed = body.trim()
        if (trimmed.isEmpty() && !isSystem) {
            return null
        }

        val buyer = if (sender.role == UserRole.BUYER) sender else recipient
        val seller = if (sender.role == UserRole.SELLER) sender else recipient
        val baseThread = ensureConversation(listing, buyer, seller)
        val updatedThread = baseThread.copy(
            updatedAt = System.currentTimeMillis(),
            messages = baseThread.messages + ConversationMessage(
                id = UUID.randomUUID().toString(),
                senderId = sender.id,
                sentAt = System.currentTimeMillis(),
                body = trimmed,
                isSystem = isSystem,
                saleTaskTarget = saleTaskTarget
            )
        )

        conversations = conversations
            .filterNot { it.id == updatedThread.id }
            .let { listOf(updatedThread) + it }
        persist()

        if (!isEphemeral) {
            runCatching {
                syncService.upsertConversation(updatedThread)
            }.onSuccess { syncedThread ->
                mergeRemoteThreads(listOf(syncedThread))
            }
        }

        return updatedThread
    }

    suspend fun sendContractPacket(
        listing: SaleListing,
        offerId: String,
        buyer: MarketplaceUserProfile,
        seller: MarketplaceUserProfile,
        packet: ContractPacket,
        triggeredBy: MarketplaceUserProfile
    ) {
        val recipient = if (triggeredBy.id == buyer.id) seller else buyer
        val summary = """
            Contract packet sent to both parties.
            Buyer legal representative: ${packet.buyerRepresentative.name} (${packet.buyerRepresentative.primarySpecialty})
            Seller legal representative: ${packet.sellerRepresentative.name} (${packet.sellerRepresentative.primarySpecialty})
            ${packet.summary}
        """.trimIndent()

        sendMessage(
            listing = listing,
            sender = triggeredBy,
            recipient = recipient,
            body = summary,
            isSystem = true,
            saleTaskTarget = ConversationSaleTaskTarget(
                listingId = listing.id,
                offerId = offerId,
                checklistItemId = "contract-packet"
            )
        )
    }

    private suspend fun ensureConversation(
        listing: SaleListing,
        buyer: MarketplaceUserProfile,
        seller: MarketplaceUserProfile
    ): ConversationThread {
        threadFor(listing.id, buyer.id, seller.id)?.let { return it }

        val thread = ConversationThread(
            id = UUID.randomUUID().toString(),
            listingId = listing.id,
            participantIds = listOf(buyer.id, seller.id),
            encryptionLabel = "AES-GCM local vault",
            updatedAt = System.currentTimeMillis(),
            messages = listOf(
                ConversationMessage(
                    id = UUID.randomUUID().toString(),
                    senderId = seller.id,
                    sentAt = System.currentTimeMillis(),
                    body = "Secure private channel opened for ${listing.title}. Ask about inspections, contracts, or terms here.",
                    isSystem = true,
                    saleTaskTarget = null
                )
            )
        )

        conversations = listOf(thread) + conversations
        persist()

        if (!isEphemeral) {
            runCatching {
                syncService.upsertConversation(thread)
            }.onSuccess { syncedThread ->
                mergeRemoteThreads(listOf(syncedThread))
            }
        }

        return thread
    }

    private fun mergeRemoteThreads(remoteThreads: List<ConversationThread>) {
        if (remoteThreads.isEmpty()) {
            return
        }

        val merged = conversations.associateBy { it.id }.toMutableMap()
        remoteThreads.forEach { thread ->
            merged[thread.id] = thread
        }

        conversations = merged.values.sortedByDescending { it.updatedAt }
        persist()
    }

    private fun load() {
        runCatching {
            if (!storageFile.exists()) {
                return
            }

            val encrypted = storageFile.readBytes()
            if (encrypted.isEmpty()) {
                return
            }

            val snapshot = json.decodeFromString<ConversationSnapshot>(
                vault.decrypt(encrypted).decodeToString()
            )
            conversations = snapshot.conversations.sortedByDescending { it.updatedAt }
        }
    }

    private fun persist() {
        if (isEphemeral) {
            return
        }

        runCatching {
            storageFile.parentFile?.mkdirs()
            val snapshot = ConversationSnapshot(conversations = conversations)
            val encrypted = vault.encrypt(json.encodeToString(snapshot).encodeToByteArray())
            storageFile.writeBytes(encrypted)
        }
    }
}

private class ConversationVault {
    companion object {
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALIAS = "real_o_who_conversation_store"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_LENGTH_BYTES = 12
    }

    fun encrypt(plaintext: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, loadOrCreateKey())
        val iv = cipher.iv
        val ciphertext = cipher.doFinal(plaintext)
        return ByteBuffer.allocate(4 + iv.size + ciphertext.size)
            .putInt(iv.size)
            .put(iv)
            .put(ciphertext)
            .array()
    }

    fun decrypt(payload: ByteArray): ByteArray {
        val buffer = ByteBuffer.wrap(payload)
        val ivLength = buffer.int
        require(ivLength in 1..IV_LENGTH_BYTES * 2)
        val iv = ByteArray(ivLength)
        buffer.get(iv)
        val ciphertext = ByteArray(buffer.remaining())
        buffer.get(ciphertext)

        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            loadOrCreateKey(),
            GCMParameterSpec(128, iv)
        )
        return cipher.doFinal(ciphertext)
    }

    private fun loadOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply {
            load(null)
        }
        val existingKey = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existingKey != null) {
            return existingKey
        }

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE_PROVIDER
        )
        keyGenerator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .setKeySize(256)
                .build()
        )
        return keyGenerator.generateKey()
    }
}
