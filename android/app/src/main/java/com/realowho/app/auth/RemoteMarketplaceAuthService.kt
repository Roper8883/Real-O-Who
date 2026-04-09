package com.realowho.app.auth

import java.time.Instant
import kotlinx.serialization.Serializable

@Serializable
private data class RemoteAuthSignInRequest(
    val email: String,
    val password: String
)

@Serializable
private data class RemoteAuthSignUpRequest(
    val name: String,
    val email: String,
    val password: String,
    val role: UserRole,
    val suburb: String
)

@Serializable
private data class RemoteUserProfilePayload(
    val id: String,
    val name: String,
    val role: UserRole,
    val suburb: String,
    val headline: String,
    val verificationNote: String,
    val buyerStage: String? = null,
    val createdAt: String
) {
    fun toAppModel(): MarketplaceUserProfile {
        return MarketplaceUserProfile(
            id = id,
            name = name,
            role = role,
            suburb = suburb,
            headline = headline,
            verificationNote = verificationNote,
            buyerStage = buyerStage,
            createdAt = parseMillis(createdAt)
        )
    }
}

@Serializable
private data class RemoteAuthAccountPayload(
    val id: String,
    val userId: String,
    val email: String,
    val passwordSaltBase64: String,
    val passwordHashBase64: String,
    val createdAt: String,
    val lastSignedInAt: String? = null
) {
    fun toAppModel(): LocalAuthAccount {
        return LocalAuthAccount(
            id = id,
            userId = userId,
            email = email,
            passwordSaltBase64 = passwordSaltBase64,
            passwordHashBase64 = passwordHashBase64,
            createdAt = parseMillis(createdAt),
            lastSignedInAt = lastSignedInAt?.let(::parseMillis)
        )
    }
}

@Serializable
private data class RemoteAuthEnvelope(
    val user: RemoteUserProfilePayload,
    val account: RemoteAuthAccountPayload
) {
    fun toAppModel(): MarketplaceAuthSession {
        return MarketplaceAuthSession(
            user = user.toAppModel(),
            account = account.toAppModel()
        )
    }
}

class RemoteMarketplaceAuthService(
    private val client: MarketplaceBackendClient
) : MarketplaceAuthService {
    override suspend fun signIn(
        email: String,
        password: String,
        accounts: List<LocalAuthAccount>,
        users: List<MarketplaceUserProfile>
    ): MarketplaceAuthSession {
        val response: RemoteAuthEnvelope = client.post(
            path = "v1/auth/sign-in",
            body = RemoteAuthSignInRequest(email = email, password = password)
        )
        return response.toAppModel()
    }

    override suspend fun createAccount(
        registration: MarketplaceAuthRegistration,
        existingAccounts: List<LocalAuthAccount>
    ): MarketplaceAuthSession {
        val response: RemoteAuthEnvelope = client.post(
            path = "v1/auth/sign-up",
            body = RemoteAuthSignUpRequest(
                name = registration.name,
                email = registration.email,
                password = registration.password,
                role = registration.role,
                suburb = registration.suburb
            )
        )
        return response.toAppModel()
    }
}

class FallbackMarketplaceAuthService(
    private val remote: RemoteMarketplaceAuthService,
    private val local: LocalMarketplaceAuthService
) : MarketplaceAuthService {
    override suspend fun signIn(
        email: String,
        password: String,
        accounts: List<LocalAuthAccount>,
        users: List<MarketplaceUserProfile>
    ): MarketplaceAuthSession {
        return try {
            remote.signIn(email, password, accounts, users)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.signIn(email, password, accounts, users)
            } else {
                throw MarketplaceAuthException.BackendFailure(error.message)
            }
        }
    }

    override suspend fun createAccount(
        registration: MarketplaceAuthRegistration,
        existingAccounts: List<LocalAuthAccount>
    ): MarketplaceAuthSession {
        return try {
            remote.createAccount(registration, existingAccounts)
        } catch (error: MarketplaceRemoteException) {
            if (error.canFallback) {
                local.createAccount(registration, existingAccounts)
            } else {
                throw MarketplaceAuthException.BackendFailure(error.message)
            }
        }
    }
}

object MarketplaceAuthServiceFactory {
    fun create(config: MarketplaceBackendConfig): MarketplaceAuthService {
        if (config.mode == MarketplaceRemoteMode.LOCAL_ONLY || config.baseUrl.isNullOrBlank()) {
            return LocalMarketplaceAuthService()
        }

        return FallbackMarketplaceAuthService(
            remote = RemoteMarketplaceAuthService(MarketplaceBackendClient(config)),
            local = LocalMarketplaceAuthService()
        )
    }
}

private fun parseMillis(rawValue: String): Long {
    return runCatching { Instant.parse(rawValue).toEpochMilli() }
        .getOrElse { System.currentTimeMillis() }
}
