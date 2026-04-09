package com.realowho.app.marketplace

import com.realowho.app.AppLaunchConfiguration
import com.realowho.app.auth.MarketplaceBackendClient
import com.realowho.app.auth.MarketplaceBackendConfig
import com.realowho.app.auth.MarketplaceRemoteException
import com.realowho.app.auth.MarketplaceRemoteMode
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

interface LegalProfessionalSearchService {
    suspend fun searchNear(listing: SaleListing): List<LegalProfessional>
}

class LocalLegalProfessionalSearchService : LegalProfessionalSearchService {
    override suspend fun searchNear(listing: SaleListing): List<LegalProfessional> {
        return fallbackProfessionals
            .map { professional ->
                professional to distanceInKm(
                    latitudeA = listing.latitude,
                    longitudeA = listing.longitude,
                    latitudeB = professional.latitude,
                    longitudeB = professional.longitude
                )
            }
            .filter { (professional, distanceKm) ->
                distanceKm <= 120 || professional.suburb.contains(listing.address.suburb, ignoreCase = true)
            }
            .sortedWith(
                compareBy<Pair<LegalProfessional, Double>> { it.second }
                    .thenByDescending { it.first.rating ?: 0.0 }
            )
            .take(8)
            .map { (professional, distanceKm) ->
                professional.copy(
                    searchSummary = "${professional.searchSummary} Approx. ${"%.1f".format(distanceKm)} km from the property."
                )
            }
    }

    private fun distanceInKm(
        latitudeA: Double,
        longitudeA: Double,
        latitudeB: Double,
        longitudeB: Double
    ): Double {
        val earthRadiusKm = 6371.0
        val deltaLatitude = Math.toRadians(latitudeB - latitudeA)
        val deltaLongitude = Math.toRadians(longitudeB - longitudeA)
        val startLatitude = Math.toRadians(latitudeA)
        val endLatitude = Math.toRadians(latitudeB)

        val a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2) +
            cos(startLatitude) * cos(endLatitude) *
            sin(deltaLongitude / 2) * sin(deltaLongitude / 2)

        return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    companion object {
        private val fallbackProfessionals = listOf(
            LegalProfessional(
                id = "local-brisbane-conveyancing-group",
                name = "Brisbane Conveyancing Group",
                specialties = listOf("Conveyancing", "Contract review"),
                address = "Level 8, 123 Adelaide Street, Brisbane City QLD 4000",
                suburb = "Brisbane City",
                phoneNumber = "(07) 3123 4501",
                websiteUrl = "https://example.com/brisbane-conveyancing-group",
                mapsUrl = "https://maps.google.com/?q=123+Adelaide+Street+Brisbane+City+QLD+4000",
                latitude = -27.4685,
                longitude = 153.0286,
                rating = 4.8,
                reviewCount = 61,
                source = LegalProfessionalSource.LOCAL_FALLBACK,
                searchSummary = "Handles private-sale contracts, cooling-off clauses, and settlement coordination."
            ),
            LegalProfessional(
                id = "local-rivercity-property-law",
                name = "Rivercity Property Law",
                specialties = listOf("Property solicitor", "Settlement support"),
                address = "42 Eagle Street, Brisbane City QLD 4000",
                suburb = "Brisbane City",
                phoneNumber = "(07) 3555 1180",
                websiteUrl = "https://example.com/rivercity-property-law",
                mapsUrl = "https://maps.google.com/?q=42+Eagle+Street+Brisbane+City+QLD+4000",
                latitude = -27.4708,
                longitude = 153.0304,
                rating = 4.7,
                reviewCount = 49,
                source = LegalProfessionalSource.LOCAL_FALLBACK,
                searchSummary = "Property-law team with contract preparation and buyer-seller signing support."
            ),
            LegalProfessional(
                id = "local-west-end-settlement",
                name = "West End Settlement Co",
                specialties = listOf("Conveyancing", "Buyer support"),
                address = "19 Boundary Street, West End QLD 4101",
                suburb = "West End",
                phoneNumber = "(07) 3844 9082",
                websiteUrl = "https://example.com/west-end-settlement",
                mapsUrl = "https://maps.google.com/?q=19+Boundary+Street+West+End+QLD+4101",
                latitude = -27.4812,
                longitude = 153.0099,
                rating = 4.6,
                reviewCount = 34,
                source = LegalProfessionalSource.LOCAL_FALLBACK,
                searchSummary = "Popular with owner-sellers wanting fixed-fee contract work and settlement checklists."
            ),
            LegalProfessional(
                id = "local-bulimba-legal",
                name = "Bulimba Legal & Conveyancing",
                specialties = listOf("Property lawyer", "Contract negotiation"),
                address = "77 Oxford Street, Bulimba QLD 4171",
                suburb = "Bulimba",
                phoneNumber = "(07) 3399 4412",
                websiteUrl = "https://example.com/bulimba-legal",
                mapsUrl = "https://maps.google.com/?q=77+Oxford+Street+Bulimba+QLD+4171",
                latitude = -27.4523,
                longitude = 153.0577,
                rating = 4.8,
                reviewCount = 27,
                source = LegalProfessionalSource.LOCAL_FALLBACK,
                searchSummary = "Focuses on residential contracts, amendments, and pre-settlement issue resolution."
            ),
            LegalProfessional(
                id = "local-logan-private-sale-law",
                name = "Logan Private Sale Law",
                specialties = listOf("Solicitor", "Private sale paperwork"),
                address = "3 Wembley Road, Logan Central QLD 4114",
                suburb = "Logan Central",
                phoneNumber = "(07) 3290 7750",
                websiteUrl = "https://example.com/logan-private-sale-law",
                mapsUrl = "https://maps.google.com/?q=3+Wembley+Road+Logan+Central+QLD+4114",
                latitude = -27.6394,
                longitude = 153.1093,
                rating = 4.5,
                reviewCount = 18,
                source = LegalProfessionalSource.LOCAL_FALLBACK,
                searchSummary = "Helps private buyers and sellers handle contract exchange and settlement scheduling."
            )
        )
    }
}

@Serializable
private data class RemoteLegalProfessionalEnvelope(
    val professionals: List<RemoteLegalProfessionalPayload> = emptyList()
)

@Serializable
private data class RemoteLegalProfessionalPayload(
    val id: String,
    val name: String,
    val specialties: List<String> = emptyList(),
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

class RemoteLegalProfessionalSearchService(
    private val client: MarketplaceBackendClient
) : LegalProfessionalSearchService {
    override suspend fun searchNear(listing: SaleListing): List<LegalProfessional> {
        val response: RemoteLegalProfessionalEnvelope = client.get(
            path = "v1/legal-professionals/search",
            queryParameters = mapOf(
                "lat" to listing.latitude.toString(),
                "lng" to listing.longitude.toString(),
                "suburb" to listing.address.suburb,
                "state" to listing.address.state,
                "postcode" to listing.address.postcode
            )
        )

        return response.professionals.map { it.toAppModel() }
    }
}

class FallbackLegalProfessionalSearchService(
    private val remote: RemoteLegalProfessionalSearchService,
    private val local: LocalLegalProfessionalSearchService,
    private val backendConfig: MarketplaceBackendConfig
) : LegalProfessionalSearchService {
    override suspend fun searchNear(listing: SaleListing): List<LegalProfessional> {
        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local.searchNear(listing)
        }

        return try {
            val remoteResults = remote.searchNear(listing)
            if (remoteResults.isEmpty()) {
                local.searchNear(listing)
            } else {
                remoteResults
            }
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.searchNear(listing)
            } else {
                throw error
            }
        }
    }
}

object LegalProfessionalSearchServiceFactory {
    fun create(launchConfiguration: AppLaunchConfiguration): LegalProfessionalSearchService {
        val backendConfig = MarketplaceBackendConfig.launchDefault(launchConfiguration)
        val local = LocalLegalProfessionalSearchService()

        if (backendConfig.mode != MarketplaceRemoteMode.REMOTE_PREFERRED) {
            return local
        }

        return FallbackLegalProfessionalSearchService(
            remote = RemoteLegalProfessionalSearchService(MarketplaceBackendClient(backendConfig)),
            local = local,
            backendConfig = backendConfig
        )
    }
}
