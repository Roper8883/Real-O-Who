package com.realowho.app.marketplace

import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.auth.MarketplaceBackendClient
import com.realowho.app.auth.MarketplaceBackendConfig
import com.realowho.app.auth.MarketplaceRemoteException
import com.realowho.app.auth.MarketplaceRemoteMode
import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

interface MarketplaceExperienceSyncService {
    suspend fun fetchListings(): List<MarketplaceListing>
    suspend fun fetchUserState(userId: String): MarketplaceUserState
    suspend fun upsertUserState(state: MarketplaceUserState): MarketplaceUserState
}

@Serializable
private data class RemoteListingListEnvelope(
    val listings: List<RemoteListingPayload> = emptyList()
)

@Serializable
private data class RemoteMarketplaceStateEnvelope(
    val state: RemoteMarketplaceStatePayload
)

@Serializable
private data class RemoteListingPayload(
    val id: String,
    val title: String,
    val headline: String,
    val summary: String,
    val propertyType: MarketplacePropertyType,
    val status: MarketplaceListingStatus,
    val address: RemotePropertyAddressPayload,
    val askingPrice: Int,
    val bedrooms: Int,
    val bathrooms: Int,
    val parkingSpaces: Int,
    val landSizeText: String,
    val features: List<String>,
    @SerialName("sellerID")
    val sellerId: String,
    val isFeatured: Boolean,
    val publishedAt: String,
    val updatedAt: String
) {
    fun toAppModel(): MarketplaceListing {
        return MarketplaceListing(
            id = id,
            title = title,
            headline = headline,
            summary = summary,
            propertyType = propertyType,
            status = status,
            address = address.toAppModel(),
            askingPrice = askingPrice,
            bedrooms = bedrooms,
            bathrooms = bathrooms,
            parkingSpaces = parkingSpaces,
            landSizeText = landSizeText,
            features = features,
            sellerId = sellerId,
            isFeatured = isFeatured,
            publishedAt = publishedAt.toEpochMillis(),
            updatedAt = updatedAt.toEpochMillis()
        )
    }
}

@Serializable
private data class RemotePropertyAddressPayload(
    val street: String,
    val suburb: String,
    val state: String,
    val postcode: String
) {
    fun toAppModel(): MarketplacePropertyAddress {
        return MarketplacePropertyAddress(
            street = street,
            suburb = suburb,
            state = state,
            postcode = postcode
        )
    }
}

@Serializable
private data class RemoteMarketplaceStatePayload(
    @SerialName("userID")
    val userId: String,
    val favoriteListingIDs: List<String> = emptyList(),
    val savedSearches: List<RemoteSavedSearchPayload> = emptyList()
) {
    fun toAppModel(): MarketplaceUserState {
        return MarketplaceUserState(
            userId = userId,
            favoriteListingIds = favoriteListingIDs.toSet(),
            savedSearches = savedSearches.map { it.toAppModel() }
        )
    }
}

@Serializable
private data class RemoteSavedSearchPayload(
    val id: String,
    val title: String,
    val suburb: String,
    val minimumPrice: Int,
    val maximumPrice: Int,
    val minimumBedrooms: Int,
    val propertyTypes: List<MarketplacePropertyType> = emptyList(),
    val alertsEnabled: Boolean
) {
    fun toAppModel(): MarketplaceSavedSearch {
        return MarketplaceSavedSearch(
            id = id,
            title = title,
            suburb = suburb,
            minimumPrice = minimumPrice,
            maximumPrice = maximumPrice,
            minimumBedrooms = minimumBedrooms,
            propertyTypes = propertyTypes,
            alertsEnabled = alertsEnabled
        )
    }
}

private fun MarketplaceUserState.toRemotePayload(): RemoteMarketplaceStatePayload {
    return RemoteMarketplaceStatePayload(
        userId = userId,
        favoriteListingIDs = favoriteListingIds.toList(),
        savedSearches = savedSearches.map { search ->
            RemoteSavedSearchPayload(
                id = search.id,
                title = search.title,
                suburb = search.suburb,
                minimumPrice = search.minimumPrice,
                maximumPrice = search.maximumPrice,
                minimumBedrooms = search.minimumBedrooms,
                propertyTypes = search.propertyTypes,
                alertsEnabled = search.alertsEnabled
            )
        }
    )
}

private class DisabledMarketplaceExperienceSyncService : MarketplaceExperienceSyncService {
    override suspend fun fetchListings(): List<MarketplaceListing> = MarketplaceExperienceSeed.listings

    override suspend fun fetchUserState(userId: String): MarketplaceUserState = MarketplaceExperienceSeed.stateFor(userId)

    override suspend fun upsertUserState(state: MarketplaceUserState): MarketplaceUserState = state
}

private class RemoteMarketplaceExperienceSyncService(
    private val client: MarketplaceBackendClient
) : MarketplaceExperienceSyncService {
    override suspend fun fetchListings(): List<MarketplaceListing> {
        val response: RemoteListingListEnvelope = client.get(path = "v1/listings")
        return response.listings.map { it.toAppModel() }
    }

    override suspend fun fetchUserState(userId: String): MarketplaceUserState {
        val response: RemoteMarketplaceStateEnvelope = client.get(path = "v1/marketplace-state/$userId")
        return response.state.toAppModel()
    }

    override suspend fun upsertUserState(state: MarketplaceUserState): MarketplaceUserState {
        val response: RemoteMarketplaceStateEnvelope = client.requestWithBody(
            path = "v1/marketplace-state/${state.userId}",
            method = "PUT",
            body = RemoteMarketplaceStateEnvelope(state = state.toRemotePayload())
        )
        return response.state.toAppModel()
    }
}

private class FallbackMarketplaceExperienceSyncService(
    private val remote: RemoteMarketplaceExperienceSyncService,
    private val local: DisabledMarketplaceExperienceSyncService,
    private val backendConfig: MarketplaceBackendConfig
) : MarketplaceExperienceSyncService {
    override suspend fun fetchListings(): List<MarketplaceListing> {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.fetchListings()
        }

        return try {
            val remoteListings = remote.fetchListings()
            if (remoteListings.isEmpty()) local.fetchListings() else remoteListings
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.fetchListings()
            } else {
                throw error
            }
        }
    }

    override suspend fun fetchUserState(userId: String): MarketplaceUserState {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.fetchUserState(userId)
        }

        return try {
            remote.fetchUserState(userId)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.fetchUserState(userId)
            } else {
                throw error
            }
        }
    }

    override suspend fun upsertUserState(state: MarketplaceUserState): MarketplaceUserState {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.upsertUserState(state)
        }

        return try {
            remote.upsertUserState(state)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.upsertUserState(state)
            } else {
                throw error
            }
        }
    }
}

object MarketplaceExperienceSyncServiceFactory {
    fun create(launchConfiguration: AppLaunchConfiguration): MarketplaceExperienceSyncService {
        val backendConfig = MarketplaceBackendConfig.launchDefault(launchConfiguration)
        val local = DisabledMarketplaceExperienceSyncService()

        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local
        }

        return FallbackMarketplaceExperienceSyncService(
            remote = RemoteMarketplaceExperienceSyncService(MarketplaceBackendClient(backendConfig)),
            local = local,
            backendConfig = backendConfig
        )
    }
}

private fun String.toEpochMillis(): Long {
    return runCatching { Instant.parse(this).toEpochMilli() }
        .getOrElse { System.currentTimeMillis() }
}
