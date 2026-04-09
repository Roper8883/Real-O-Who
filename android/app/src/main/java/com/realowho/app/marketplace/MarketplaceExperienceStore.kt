package com.realowho.app.marketplace

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.realowho.app.AppLaunchConfiguration
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class MarketplaceExperienceStore(
    context: Context,
    launchConfiguration: AppLaunchConfiguration,
    syncService: MarketplaceExperienceSyncService? = null
) {
    private val syncService = syncService ?: MarketplaceExperienceSyncServiceFactory.create(launchConfiguration)
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
    }
    private val storageFile = File(
        File(context.filesDir, "real-o-who-marketplace"),
        "marketplace-experience.json"
    )
    private val isEphemeral = launchConfiguration.isScreenshotMode
    private val syncScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    var listings by mutableStateOf(MarketplaceExperienceSeed.listings)
        private set

    private var userStatesById by mutableStateOf<Map<String, MarketplaceUserState>>(emptyMap())

    init {
        if (!isEphemeral) {
            load()
        }
    }

    fun stateFor(userId: String): MarketplaceUserState {
        return userStatesById[userId] ?: MarketplaceExperienceSeed.stateFor(userId)
    }

    fun favoriteListings(userId: String): List<MarketplaceListing> {
        val favoriteIds = stateFor(userId).favoriteListingIds
        return listings.filter { favoriteIds.contains(it.id) }
    }

    fun savedSearches(userId: String): List<MarketplaceSavedSearch> {
        return stateFor(userId).savedSearches
    }

    fun isFavorite(userId: String, listingId: String): Boolean {
        return stateFor(userId).favoriteListingIds.contains(listingId)
    }

    fun filteredListings(
        query: String,
        suburb: String,
        minimumBedrooms: Int,
        maximumPrice: Int?,
        propertyTypes: Set<MarketplacePropertyType>
    ): List<MarketplaceListing> {
        val normalizedQuery = query.trim().lowercase()
        val normalizedSuburb = suburb.trim().lowercase()

        return listings
            .filter { listing ->
                if (listing.status == MarketplaceListingStatus.DRAFT || listing.status == MarketplaceListingStatus.SOLD) {
                    return@filter false
                }

                if (minimumBedrooms > 0 && listing.bedrooms < minimumBedrooms) {
                    return@filter false
                }

                if (maximumPrice != null && listing.askingPrice > maximumPrice) {
                    return@filter false
                }

                if (propertyTypes.isNotEmpty() && listing.propertyType !in propertyTypes) {
                    return@filter false
                }

                if (normalizedSuburb.isNotEmpty() && !listing.address.suburb.lowercase().contains(normalizedSuburb)) {
                    return@filter false
                }

                if (normalizedQuery.isEmpty()) {
                    return@filter true
                }

                listOf(
                    listing.title,
                    listing.headline,
                    listing.summary,
                    listing.address.fullLine,
                    listing.features.joinToString(" ")
                )
                    .joinToString(" ")
                    .lowercase()
                    .contains(normalizedQuery)
            }
            .sortedWith(
                compareByDescending<MarketplaceListing> { it.isFeatured }
                    .thenByDescending { it.updatedAt }
            )
    }

    suspend fun refreshForUser(userId: String) {
        val remoteListings = runCatching { syncService.fetchListings() }.getOrNull()
        if (!remoteListings.isNullOrEmpty()) {
            listings = remoteListings.sortedWith(
                compareByDescending<MarketplaceListing> { it.updatedAt }
                    .thenByDescending { it.publishedAt }
            )
        }

        val remoteState = runCatching { syncService.fetchUserState(userId) }.getOrNull()
        if (remoteState != null) {
            userStatesById = userStatesById + (userId to remoteState)
        } else if (userId !in userStatesById) {
            userStatesById = userStatesById + (userId to MarketplaceExperienceSeed.stateFor(userId))
        }

        persist()
    }

    fun toggleFavorite(userId: String, listingId: String) {
        val currentState = stateFor(userId)
        val updatedState = currentState.copy(
            favoriteListingIds = if (listingId in currentState.favoriteListingIds) {
                currentState.favoriteListingIds - listingId
            } else {
                currentState.favoriteListingIds + listingId
            }
        )
        updateUserState(updatedState)
    }

    fun addSavedSearch(
        userId: String,
        title: String,
        suburb: String,
        minimumPrice: Int,
        maximumPrice: Int,
        minimumBedrooms: Int,
        propertyTypes: Set<MarketplacePropertyType>
    ) {
        val trimmedTitle = title.trim()
        if (trimmedTitle.isEmpty()) {
            return
        }

        val currentState = stateFor(userId)
        val updatedState = currentState.copy(
            savedSearches = listOf(
                MarketplaceSavedSearch(
                    id = java.util.UUID.randomUUID().toString(),
                    title = trimmedTitle,
                    suburb = suburb.trim(),
                    minimumPrice = minimumPrice,
                    maximumPrice = maximumPrice,
                    minimumBedrooms = minimumBedrooms,
                    propertyTypes = propertyTypes.toList(),
                    alertsEnabled = true
                )
            ) + currentState.savedSearches
        )
        updateUserState(updatedState)
    }

    fun toggleSavedSearchAlerts(userId: String, searchId: String) {
        val currentState = stateFor(userId)
        val updatedState = currentState.copy(
            savedSearches = currentState.savedSearches.map { search ->
                if (search.id == searchId) {
                    search.copy(alertsEnabled = !search.alertsEnabled)
                } else {
                    search
                }
            }
        )
        updateUserState(updatedState)
    }

    private fun updateUserState(state: MarketplaceUserState) {
        userStatesById = userStatesById + (state.userId to state)
        persist()

        if (isEphemeral) {
            return
        }

        syncScope.launch {
            runCatching {
                syncService.upsertUserState(state)
            }.onSuccess { syncedState ->
                userStatesById = userStatesById + (syncedState.userId to syncedState)
                persist()
            }
        }
    }

    private fun load() {
        runCatching {
            if (!storageFile.exists()) {
                return
            }

            val snapshot = json.decodeFromString<MarketplaceExperienceSnapshot>(storageFile.readText())
            if (snapshot.listings.isNotEmpty()) {
                listings = snapshot.listings
            }
            userStatesById = snapshot.userStates.associateBy { it.userId }
        }
    }

    private fun persist() {
        if (isEphemeral) {
            return
        }

        runCatching {
            storageFile.parentFile?.mkdirs()
            storageFile.writeText(
                json.encodeToString(
                    MarketplaceExperienceSnapshot(
                        listings = listings,
                        userStates = userStatesById.values.sortedBy { it.userId }
                    )
                )
            )
        }
    }
}
