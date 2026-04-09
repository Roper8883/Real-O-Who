package com.realowho.app.marketplace

import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.auth.MarketplaceBackendClient
import com.realowho.app.auth.MarketplaceBackendConfig
import com.realowho.app.auth.MarketplaceRemoteException
import com.realowho.app.auth.MarketplaceRemoteMode
import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

interface SaleCoordinationSyncService {
    suspend fun fetchListing(listingId: String): SaleListing?
    suspend fun fetchSale(listingId: String): SaleOffer?
    suspend fun fetchLegalWorkspace(inviteCode: String): Triple<SaleListing, SaleOffer, SaleWorkspaceInvite>?
    suspend fun upsertSale(offer: SaleOffer): SaleOffer
}

private object SaleCoordinationIds {
    const val FALLBACK_BUYER_ID = "C8F18F9D-772E-4D62-8A88-0B9E23265002"
    const val FALLBACK_SELLER_ID = "C8F18F9D-772E-4D62-8A88-0B9E23265004"
}

@Serializable
private data class RemoteSaleEnvelope(
    val sale: RemoteSalePayload? = null
)

@Serializable
private data class RemoteListingEnvelope(
    val listing: RemoteSaleListingPayload? = null
)

@Serializable
private data class RemoteLegalWorkspaceEnvelope(
    val listing: RemoteSaleListingPayload? = null,
    val sale: RemoteSalePayload? = null,
    val invite: RemoteSaleWorkspaceInvitePayload? = null
)

@Serializable
private data class RemoteSaleListingPayload(
    val id: String,
    val title: String,
    val summary: String,
    val address: RemoteSaleListingAddressPayload,
    val askingPrice: Int,
    val bedrooms: Int,
    val bathrooms: Int,
    val parkingSpaces: Int,
    val latitude: Double,
    val longitude: Double
) {
    fun toAppModel(): SaleListing {
        return SaleListing(
            id = id,
            title = title,
            summary = summary,
            address = address.toAppModel(),
            askingPrice = askingPrice,
            bedrooms = bedrooms,
            bathrooms = bathrooms,
            parkingSpaces = parkingSpaces,
            latitude = latitude,
            longitude = longitude
        )
    }
}

@Serializable
private data class RemoteSaleListingAddressPayload(
    val street: String,
    val suburb: String,
    val state: String,
    val postcode: String
) {
    fun toAppModel(): SalePropertyAddress {
        return SalePropertyAddress(
            street = street,
            suburb = suburb,
            state = state,
            postcode = postcode
        )
    }
}

@Serializable
private data class RemoteSalePayload(
    val id: String,
    @SerialName("listingID")
    val listingId: String,
    @SerialName("buyerID")
    val buyerId: String,
    @SerialName("sellerID")
    val sellerId: String,
    val amount: Int,
    val conditions: String,
    val createdAt: String,
    val status: SaleOfferStatus = SaleOfferStatus.UNDER_OFFER,
    val buyerLegalSelection: RemoteLegalSelectionPayload? = null,
    val sellerLegalSelection: RemoteLegalSelectionPayload? = null,
    val contractPacket: RemoteContractPacketPayload? = null,
    val invites: List<RemoteSaleWorkspaceInvitePayload> = emptyList(),
    val documents: List<RemoteSaleDocumentPayload> = emptyList(),
    val updates: List<RemoteSaleUpdatePayload> = emptyList()
) {
    fun toAppModel(): SaleOffer {
        return SaleOffer(
            id = id,
            listingId = listingId,
            buyerId = buyerId,
            sellerId = sellerId,
            amount = amount,
            conditions = conditions,
            createdAt = createdAt.toEpochMillis(),
            status = status,
            buyerLegalSelection = buyerLegalSelection?.toAppModel(com.realowho.app.auth.UserRole.BUYER),
            sellerLegalSelection = sellerLegalSelection?.toAppModel(com.realowho.app.auth.UserRole.SELLER),
            contractPacket = contractPacket?.toAppModel(),
            invites = invites.map { it.toAppModel() },
            documents = documents.map { it.toAppModel() },
            updates = updates.map { it.toAppModel() }
        )
    }
}

@Serializable
private data class RemoteSaleUpdatePayload(
    val id: String,
    val createdAt: String,
    val title: String,
    val body: String,
    val kind: SaleUpdateKind = SaleUpdateKind.MILESTONE
) {
    fun toAppModel(): SaleUpdateMessage {
        return SaleUpdateMessage(
            id = id,
            createdAt = createdAt.toEpochMillis(),
            title = title,
            body = body,
            kind = kind
        )
    }
}

@Serializable
private data class RemoteLegalSelectionPayload(
    @SerialName("userID")
    val userId: String,
    val selectedAt: String,
    val professional: RemoteSaleLegalProfessionalPayload
) {
    fun toAppModel(role: com.realowho.app.auth.UserRole): LegalSelection {
        return LegalSelection(
            role = role,
            selectedAt = selectedAt.toEpochMillis(),
            professional = professional.toAppModel()
        )
    }
}

@Serializable
private data class RemoteContractPacketPayload(
    val id: String,
    val generatedAt: String,
    @SerialName("listingID")
    val listingId: String,
    @SerialName("offerID")
    val offerId: String,
    @SerialName("buyerID")
    val buyerId: String,
    @SerialName("sellerID")
    val sellerId: String,
    val buyerRepresentative: RemoteSaleLegalProfessionalPayload,
    val sellerRepresentative: RemoteSaleLegalProfessionalPayload,
    val summary: String,
    val buyerSignedAt: String? = null,
    val sellerSignedAt: String? = null
) {
    fun toAppModel(): ContractPacket {
        return ContractPacket(
            id = id,
            generatedAt = generatedAt.toEpochMillis(),
            listingId = listingId,
            offerId = offerId,
            buyerId = buyerId,
            sellerId = sellerId,
            buyerRepresentative = buyerRepresentative.toAppModel(),
            sellerRepresentative = sellerRepresentative.toAppModel(),
            summary = summary,
            buyerSignedAt = buyerSignedAt?.toEpochMillis(),
            sellerSignedAt = sellerSignedAt?.toEpochMillis()
        )
    }
}

@Serializable
private data class RemoteSaleDocumentPayload(
    val id: String,
    val kind: SaleDocumentKind,
    val createdAt: String,
    val fileName: String,
    val summary: String,
    @SerialName("uploadedByUserID")
    val uploadedByUserId: String,
    val uploadedByName: String,
    @SerialName("packetID")
    val packetId: String? = null,
    val mimeType: String? = null,
    val attachmentBase64: String? = null
) {
    fun toAppModel(): SaleDocument {
        return SaleDocument(
            id = id,
            kind = kind,
            createdAt = createdAt.toEpochMillis(),
            fileName = fileName,
            summary = summary,
            uploadedByUserId = uploadedByUserId,
            uploadedByName = uploadedByName,
            packetId = packetId,
            mimeType = mimeType,
            attachmentBase64 = attachmentBase64
        )
    }
}

@Serializable
private data class RemoteSaleWorkspaceInvitePayload(
    val id: String,
    val role: LegalInviteRole,
    val createdAt: String,
    val professionalName: String,
    val professionalSpecialty: String,
    val shareCode: String,
    val shareMessage: String,
    val expiresAt: String,
    val activatedAt: String? = null,
    val revokedAt: String? = null,
    val acknowledgedAt: String? = null,
    val lastSharedAt: String? = null,
    val shareCount: Int = 0,
    @SerialName("generatedByUserID")
    val generatedByUserId: String,
    val generatedByName: String
) {
    fun toAppModel(): SaleWorkspaceInvite {
        return SaleWorkspaceInvite(
            id = id,
            role = role,
            createdAt = createdAt.toEpochMillis(),
            professionalName = professionalName,
            professionalSpecialty = professionalSpecialty,
            shareCode = shareCode,
            shareMessage = shareMessage,
            expiresAt = expiresAt.toEpochMillis(),
            activatedAt = activatedAt?.toEpochMillis(),
            revokedAt = revokedAt?.toEpochMillis(),
            acknowledgedAt = acknowledgedAt?.toEpochMillis(),
            lastSharedAt = lastSharedAt?.toEpochMillis(),
            shareCount = shareCount.coerceAtLeast(0),
            generatedByUserId = generatedByUserId,
            generatedByName = generatedByName
        )
    }
}

@Serializable
private data class RemoteSaleLegalProfessionalPayload(
    val id: String,
    val name: String,
    val specialties: List<String>,
    val address: String,
    val suburb: String,
    val phoneNumber: String? = null,
    @SerialName("websiteURL")
    val websiteUrl: String? = null,
    @SerialName("mapsURL")
    val mapsUrl: String? = null,
    val latitude: Double,
    val longitude: Double,
    val rating: Double? = null,
    val reviewCount: Int? = null,
    val source: String,
    val searchSummary: String
) {
    fun toAppModel(): LegalProfessional {
        return LegalProfessional(
            id = id,
            name = name,
            specialties = specialties,
            address = address,
            suburb = suburb,
            phoneNumber = phoneNumber,
            websiteUrl = websiteUrl,
            mapsUrl = mapsUrl,
            latitude = latitude,
            longitude = longitude,
            rating = rating,
            reviewCount = reviewCount,
            source = if (source == "googlePlaces") {
                LegalProfessionalSource.GOOGLE_PLACES
            } else {
                LegalProfessionalSource.LOCAL_FALLBACK
            },
            searchSummary = searchSummary
        )
    }
}

class DisabledSaleCoordinationSyncService : SaleCoordinationSyncService {
    override suspend fun fetchListing(listingId: String): SaleListing? = null

    override suspend fun fetchSale(listingId: String): SaleOffer? = null

    override suspend fun fetchLegalWorkspace(inviteCode: String): Triple<SaleListing, SaleOffer, SaleWorkspaceInvite>? = null

    override suspend fun upsertSale(offer: SaleOffer): SaleOffer = offer
}

class RemoteSaleCoordinationSyncService(
    private val client: MarketplaceBackendClient
) : SaleCoordinationSyncService {
    override suspend fun fetchListing(listingId: String): SaleListing? {
        val response: RemoteListingEnvelope = client.get(
            path = "v1/listings/$listingId"
        )
        return response.listing?.toAppModel()
    }

    override suspend fun fetchSale(listingId: String): SaleOffer? {
        val response: RemoteSaleEnvelope = client.get(
            path = "v1/sales/by-listing/$listingId"
        )
        return response.sale?.toAppModel()
    }

    override suspend fun fetchLegalWorkspace(inviteCode: String): Triple<SaleListing, SaleOffer, SaleWorkspaceInvite>? {
        val response: RemoteLegalWorkspaceEnvelope = client.get(
            path = "v1/legal-workspace/$inviteCode"
        )
        val listing = response.listing?.toAppModel() ?: return null
        val sale = response.sale?.toAppModel() ?: return null
        val invite = response.invite?.toAppModel() ?: return null
        return Triple(listing, sale, invite)
    }

    override suspend fun upsertSale(offer: SaleOffer): SaleOffer {
        val response: RemoteSaleEnvelope = client.requestWithBody(
            path = "v1/sales/by-listing/${offer.listingId}",
            method = "PUT",
            body = RemoteSaleEnvelope(sale = offer.toRemotePayload())
        )
        return response.sale?.toAppModel() ?: offer
    }
}

class FallbackSaleCoordinationSyncService(
    private val remote: RemoteSaleCoordinationSyncService,
    private val local: DisabledSaleCoordinationSyncService,
    private val backendConfig: MarketplaceBackendConfig
) : SaleCoordinationSyncService {
    override suspend fun fetchListing(listingId: String): SaleListing? {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.fetchListing(listingId)
        }

        return try {
            remote.fetchListing(listingId)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.fetchListing(listingId)
            } else {
                throw error
            }
        }
    }

    override suspend fun fetchSale(listingId: String): SaleOffer? {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.fetchSale(listingId)
        }

        return try {
            remote.fetchSale(listingId)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.fetchSale(listingId)
            } else {
                throw error
            }
        }
    }

    override suspend fun fetchLegalWorkspace(inviteCode: String): Triple<SaleListing, SaleOffer, SaleWorkspaceInvite>? {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.fetchLegalWorkspace(inviteCode)
        }

        return try {
            remote.fetchLegalWorkspace(inviteCode)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.fetchLegalWorkspace(inviteCode)
            } else {
                throw error
            }
        }
    }

    override suspend fun upsertSale(offer: SaleOffer): SaleOffer {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.upsertSale(offer)
        }

        return try {
            remote.upsertSale(offer)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.upsertSale(offer)
            } else {
                throw error
            }
        }
    }
}

object SaleCoordinationSyncServiceFactory {
    fun create(launchConfiguration: AppLaunchConfiguration): SaleCoordinationSyncService {
        val backendConfig = MarketplaceBackendConfig.launchDefault(launchConfiguration)
        val local = DisabledSaleCoordinationSyncService()

        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local
        }

        return FallbackSaleCoordinationSyncService(
            remote = RemoteSaleCoordinationSyncService(MarketplaceBackendClient(backendConfig)),
            local = local,
            backendConfig = backendConfig
        )
    }
}

private fun SaleOffer.toRemotePayload(): RemoteSalePayload {
    return RemoteSalePayload(
        id = id,
        listingId = listingId,
        buyerId = buyerId,
        sellerId = sellerId,
        amount = amount,
        conditions = conditions,
        createdAt = createdAt.toIsoString(),
        status = status,
        buyerLegalSelection = buyerLegalSelection?.toRemotePayload(),
        sellerLegalSelection = sellerLegalSelection?.toRemotePayload(),
        contractPacket = contractPacket?.toRemotePayload(),
        invites = invites.map { it.toRemotePayload() },
        documents = documents.map { it.toRemotePayload() },
        updates = updates.map { it.toRemotePayload() }
    )
}

private fun SaleUpdateMessage.toRemotePayload(): RemoteSaleUpdatePayload {
    return RemoteSaleUpdatePayload(
        id = id,
        createdAt = createdAt.toIsoString(),
        title = title,
        body = body,
        kind = kind
    )
}

private fun LegalSelection.toRemotePayload(): RemoteLegalSelectionPayload {
    return RemoteLegalSelectionPayload(
        userId = if (role == com.realowho.app.auth.UserRole.BUYER) {
            SaleCoordinationIds.FALLBACK_BUYER_ID
        } else {
            SaleCoordinationIds.FALLBACK_SELLER_ID
        },
        selectedAt = selectedAt.toIsoString(),
        professional = professional.toRemotePayload()
    )
}

private fun ContractPacket.toRemotePayload(): RemoteContractPacketPayload {
    return RemoteContractPacketPayload(
        id = id,
        generatedAt = generatedAt.toIsoString(),
        listingId = listingId,
        offerId = offerId,
        buyerId = buyerId,
        sellerId = sellerId,
        buyerRepresentative = buyerRepresentative.toRemotePayload(),
        sellerRepresentative = sellerRepresentative.toRemotePayload(),
        summary = summary,
        buyerSignedAt = buyerSignedAt?.toIsoString(),
        sellerSignedAt = sellerSignedAt?.toIsoString()
    )
}

private fun SaleDocument.toRemotePayload(): RemoteSaleDocumentPayload {
    return RemoteSaleDocumentPayload(
        id = id,
        kind = kind,
        createdAt = createdAt.toIsoString(),
        fileName = fileName,
        summary = summary,
        uploadedByUserId = uploadedByUserId,
        uploadedByName = uploadedByName,
        packetId = packetId,
        mimeType = mimeType,
        attachmentBase64 = attachmentBase64
    )
}

private fun SaleWorkspaceInvite.toRemotePayload(): RemoteSaleWorkspaceInvitePayload {
    return RemoteSaleWorkspaceInvitePayload(
        id = id,
        role = role,
        createdAt = createdAt.toIsoString(),
        professionalName = professionalName,
        professionalSpecialty = professionalSpecialty,
        shareCode = shareCode,
        shareMessage = shareMessage,
        expiresAt = expiresAt.toIsoString(),
        activatedAt = activatedAt?.toIsoString(),
        revokedAt = revokedAt?.toIsoString(),
        acknowledgedAt = acknowledgedAt?.toIsoString(),
        lastSharedAt = lastSharedAt?.toIsoString(),
        shareCount = shareCount,
        generatedByUserId = generatedByUserId,
        generatedByName = generatedByName
    )
}

private fun LegalProfessional.toRemotePayload(): RemoteSaleLegalProfessionalPayload {
    return RemoteSaleLegalProfessionalPayload(
        id = id,
        name = name,
        specialties = specialties,
        address = address,
        suburb = suburb,
        phoneNumber = phoneNumber,
        websiteUrl = websiteUrl,
        mapsUrl = mapsUrl,
        latitude = latitude,
        longitude = longitude,
        rating = rating,
        reviewCount = reviewCount,
        source = if (source == LegalProfessionalSource.GOOGLE_PLACES) {
            "googlePlaces"
        } else {
            "localFallback"
        },
        searchSummary = searchSummary
    )
}

private fun Long.toIsoString(): String = Instant.ofEpochMilli(this).toString()

private fun String.toEpochMillis(): Long = runCatching { Instant.parse(this).toEpochMilli() }
    .getOrElse { System.currentTimeMillis() }
