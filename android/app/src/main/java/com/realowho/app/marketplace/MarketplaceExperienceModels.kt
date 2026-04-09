package com.realowho.app.marketplace

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class MarketplacePropertyType(val title: String) {
    @SerialName("house")
    HOUSE("House"),

    @SerialName("apartment")
    APARTMENT("Apartment"),

    @SerialName("townhouse")
    TOWNHOUSE("Townhouse"),

    @SerialName("acreage")
    ACREAGE("Acreage"),

    @SerialName("land")
    LAND("Land")
}

@Serializable
enum class MarketplaceListingStatus(val title: String) {
    @SerialName("active")
    ACTIVE("Active"),

    @SerialName("underOffer")
    UNDER_OFFER("Under offer"),

    @SerialName("sold")
    SOLD("Sold"),

    @SerialName("draft")
    DRAFT("Draft")
}

@Serializable
data class MarketplacePropertyAddress(
    val street: String,
    val suburb: String,
    val state: String,
    val postcode: String
) {
    val shortLine: String
        get() = "$street, $suburb"

    val fullLine: String
        get() = "$street, $suburb $state $postcode"
}

@Serializable
data class MarketplaceListing(
    val id: String,
    val title: String,
    val headline: String,
    val summary: String,
    val propertyType: MarketplacePropertyType,
    val status: MarketplaceListingStatus,
    val address: MarketplacePropertyAddress,
    val askingPrice: Int,
    val bedrooms: Int,
    val bathrooms: Int,
    val parkingSpaces: Int,
    val landSizeText: String,
    val features: List<String>,
    val sellerId: String,
    val isFeatured: Boolean,
    val publishedAt: Long,
    val updatedAt: Long
) {
    val factLine: String
        get() = "$bedrooms bed • $bathrooms bath • $parkingSpaces car"
}

@Serializable
data class MarketplaceSavedSearch(
    val id: String,
    val title: String,
    val suburb: String,
    val minimumPrice: Int,
    val maximumPrice: Int,
    val minimumBedrooms: Int,
    val propertyTypes: List<MarketplacePropertyType>,
    val alertsEnabled: Boolean
)

@Serializable
data class MarketplaceUserState(
    val userId: String,
    val favoriteListingIds: Set<String>,
    val savedSearches: List<MarketplaceSavedSearch>
)

@Serializable
data class MarketplaceExperienceSnapshot(
    val listings: List<MarketplaceListing> = emptyList(),
    val userStates: List<MarketplaceUserState> = emptyList()
)

object MarketplaceExperienceSeed {
    private const val BUYER_OLIVIA_ID = "C8F18F9D-772E-4D62-8A88-0B9E23265001"
    private const val BUYER_NOAH_ID = "C8F18F9D-772E-4D62-8A88-0B9E23265002"

    private fun millis(iso: String): Long {
        return java.time.Instant.parse(iso).toEpochMilli()
    }

    val listings: List<MarketplaceListing> = listOf(
        MarketplaceListing(
            id = "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971001",
            title = "Renovated Queenslander with pool and studio",
            headline = "Privately listed family home with strong school catchment appeal.",
            summary = "A bright, elevated home with open-plan living, a detached studio, landscaped yard, and flexible private inspection windows for serious buyers.",
            propertyType = MarketplacePropertyType.HOUSE,
            status = MarketplaceListingStatus.ACTIVE,
            address = MarketplacePropertyAddress(
                street = "14 Roseberry Street",
                suburb = "Graceville",
                state = "QLD",
                postcode = "4075"
            ),
            askingPrice = 1_585_000,
            bedrooms = 4,
            bathrooms = 2,
            parkingSpaces = 2,
            landSizeText = "607 sqm",
            features = listOf("Private pool", "Detached studio", "School catchment appeal", "Walk to rail", "Solar power"),
            sellerId = "C8F18F9D-772E-4D62-8A88-0B9E23265003",
            isFeatured = true,
            publishedAt = millis("2026-04-06T08:30:00Z"),
            updatedAt = millis("2026-04-08T07:10:00Z")
        ),
        MarketplaceListing(
            id = "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971002",
            title = "Architect townhouse near Newmarket village",
            headline = "Turn-key private sale with curated finishes and quick offer path.",
            summary = "A low-maintenance inner-north townhouse with high ceilings, protected outdoor entertaining, and owner-managed inspections designed for efficient private sale.",
            propertyType = MarketplacePropertyType.TOWNHOUSE,
            status = MarketplaceListingStatus.ACTIVE,
            address = MarketplacePropertyAddress(
                street = "5/32 Ashgrove Avenue",
                suburb = "Wilston",
                state = "QLD",
                postcode = "4051"
            ),
            askingPrice = 1_125_000,
            bedrooms = 3,
            bathrooms = 2,
            parkingSpaces = 2,
            landSizeText = "192 sqm",
            features = listOf("Stone kitchen", "Courtyard", "Private garage", "Walk to cafes", "Low body corporate"),
            sellerId = "C8F18F9D-772E-4D62-8A88-0B9E23265004",
            isFeatured = true,
            publishedAt = millis("2026-04-03T09:15:00Z"),
            updatedAt = millis("2026-04-08T06:45:00Z")
        ),
        MarketplaceListing(
            id = "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971003",
            title = "Leafy acreage retreat with secondary dwelling",
            headline = "Private acreage listing with strong multi-generational flexibility.",
            summary = "Set on usable land with a secondary dwelling and wide frontage, this private acreage sale is positioned for buyers seeking lifestyle space without losing access to the city.",
            propertyType = MarketplacePropertyType.ACREAGE,
            status = MarketplaceListingStatus.ACTIVE,
            address = MarketplacePropertyAddress(
                street = "88 Cedar Creek Road",
                suburb = "Samford Valley",
                state = "QLD",
                postcode = "4520"
            ),
            askingPrice = 1_895_000,
            bedrooms = 5,
            bathrooms = 3,
            parkingSpaces = 4,
            landSizeText = "1.4 ha",
            features = listOf("Secondary dwelling", "Rainwater tanks", "Horse-ready paddock", "Mountain outlook", "Large shed"),
            sellerId = "C8F18F9D-772E-4D62-8A88-0B9E23265003",
            isFeatured = false,
            publishedAt = millis("2026-03-31T07:50:00Z"),
            updatedAt = millis("2026-04-07T14:10:00Z")
        ),
        MarketplaceListing(
            id = "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004",
            title = "Corner-block apartment with city skyline views",
            headline = "Investor-friendly layout with strong recent sales evidence.",
            summary = "An upper-level apartment with panoramic views, oversized balcony, and a private-seller workflow built for fast shortlist-to-offer conversion.",
            propertyType = MarketplacePropertyType.APARTMENT,
            status = MarketplaceListingStatus.UNDER_OFFER,
            address = MarketplacePropertyAddress(
                street = "17/85 Moray Street",
                suburb = "New Farm",
                state = "QLD",
                postcode = "4005"
            ),
            askingPrice = 865_000,
            bedrooms = 2,
            bathrooms = 2,
            parkingSpaces = 1,
            landSizeText = "108 sqm",
            features = listOf("City views", "Secure parking", "Lift access", "Balcony", "Walk to riverwalk"),
            sellerId = "C8F18F9D-772E-4D62-8A88-0B9E23265004",
            isFeatured = true,
            publishedAt = millis("2026-04-04T10:05:00Z"),
            updatedAt = millis("2026-04-08T09:39:53Z")
        )
    )

    fun stateFor(userId: String): MarketplaceUserState {
        return when (userId) {
            BUYER_OLIVIA_ID -> MarketplaceUserState(
                userId = userId,
                favoriteListingIds = setOf(
                    "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971001",
                    "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004"
                ),
                savedSearches = listOf(
                    MarketplaceSavedSearch(
                        id = "7A19AB1A-B78A-440D-8308-1F95FC891001",
                        title = "Inner north family homes",
                        suburb = "Wilston",
                        minimumPrice = 950_000,
                        maximumPrice = 1_400_000,
                        minimumBedrooms = 3,
                        propertyTypes = listOf(MarketplacePropertyType.HOUSE, MarketplacePropertyType.TOWNHOUSE),
                        alertsEnabled = true
                    ),
                    MarketplaceSavedSearch(
                        id = "7A19AB1A-B78A-440D-8308-1F95FC891002",
                        title = "Graceville catchment watchlist",
                        suburb = "Graceville",
                        minimumPrice = 1_200_000,
                        maximumPrice = 1_700_000,
                        minimumBedrooms = 4,
                        propertyTypes = listOf(MarketplacePropertyType.HOUSE),
                        alertsEnabled = true
                    )
                )
            )

            BUYER_NOAH_ID -> MarketplaceUserState(
                userId = userId,
                favoriteListingIds = setOf(
                    "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004",
                    "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971002"
                ),
                savedSearches = listOf(
                    MarketplaceSavedSearch(
                        id = "7A19AB1A-B78A-440D-8308-1F95FC891011",
                        title = "Inner north buyer shortlist",
                        suburb = "Wilston",
                        minimumPrice = 900_000,
                        maximumPrice = 1_400_000,
                        minimumBedrooms = 3,
                        propertyTypes = listOf(MarketplacePropertyType.HOUSE, MarketplacePropertyType.TOWNHOUSE),
                        alertsEnabled = true
                    ),
                    MarketplaceSavedSearch(
                        id = "7A19AB1A-B78A-440D-8308-1F95FC891012",
                        title = "Riverfront apartment watch",
                        suburb = "New Farm",
                        minimumPrice = 700_000,
                        maximumPrice = 980_000,
                        minimumBedrooms = 2,
                        propertyTypes = listOf(MarketplacePropertyType.APARTMENT),
                        alertsEnabled = true
                    )
                )
            )

            else -> MarketplaceUserState(
                userId = userId,
                favoriteListingIds = emptySet(),
                savedSearches = emptyList()
            )
        }
    }
}
