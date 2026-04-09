package com.realowho.app.auth

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.realowho.app.AppLaunchConfiguration
import java.io.File
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class MarketplaceSessionStore(
    context: Context,
    launchConfiguration: AppLaunchConfiguration,
    authService: MarketplaceAuthService? = null
) {
    private val backendConfig = MarketplaceBackendConfig.launchDefault(launchConfiguration)
    private val authService = authService ?: MarketplaceAuthServiceFactory.create(backendConfig)
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
    }
    private val storageFile = File(
        File(context.filesDir, "real-o-who-marketplace"),
        "auth-session.json"
    )
    private val isEphemeral = launchConfiguration.isScreenshotMode
    private val previewUser = MarketplaceUserProfile(
        id = "preview-seller",
        name = "Alicia Seller",
        role = UserRole.SELLER,
        suburb = "Brisbane",
        headline = "Previewing a private-sale launch account with no agent commission.",
        verificationNote = "Preview account",
        createdAt = System.currentTimeMillis()
    )

    var users by mutableStateOf(listOf<MarketplaceUserProfile>())
        private set

    var authAccounts by mutableStateOf(listOf<LocalAuthAccount>())
        private set

    var sessionUserId by mutableStateOf<String?>(null)
        private set

    init {
        if (!isEphemeral) {
            load()
        }
    }

    val isAuthenticated: Boolean
        get() = isEphemeral || sessionUserId != null

    val currentUser: MarketplaceUserProfile
        get() {
            if (isEphemeral) {
                return previewUser
            }

            return users.firstOrNull { it.id == sessionUserId }
                ?: users.firstOrNull()
                ?: previewUser
        }

    val currentAccount: LocalAuthAccount?
        get() = authAccounts.firstOrNull { it.userId == currentUser.id }

    val accountCount: Int
        get() = if (isEphemeral) 1 else authAccounts.size

    val storageModeSummary: String
        get() = if (backendConfig.mode == MarketplaceRemoteMode.REMOTE_PREFERRED) {
            "Backend + local fallback"
        } else {
            "Local only"
        }

    val backendEndpointSummary: String
        get() = backendConfig.baseUrl ?: "No backend URL"

    suspend fun signIn(email: String, password: String) {
        val session = authService.signIn(
            email = email,
            password = password,
            accounts = authAccounts,
            users = users
        )

        authAccounts = if (authAccounts.any { it.id == session.account.id }) {
            authAccounts.map { account ->
                if (account.id == session.account.id) {
                    session.account
                } else {
                    account
                }
            }
        } else {
            listOf(session.account) + authAccounts
        }

        users = if (users.any { it.id == session.user.id }) {
            users.map { user ->
                if (user.id == session.user.id) {
                    session.user
                } else {
                    user
                }
            }
        } else {
            listOf(session.user) + users
        }

        sessionUserId = session.user.id
        persist()
    }

    suspend fun createAccount(
        name: String,
        email: String,
        password: String,
        role: UserRole,
        suburb: String
    ) {
        val session = authService.createAccount(
            registration = MarketplaceAuthRegistration(
                name = name,
                email = email,
                password = password,
                role = role,
                suburb = suburb
            ),
            existingAccounts = authAccounts
        )

        users = listOf(session.user) + users
        authAccounts = listOf(session.account) + authAccounts
        sessionUserId = session.user.id
        persist()
    }

    fun signOut() {
        if (isEphemeral) {
            return
        }

        sessionUserId = null
        persist()
    }

    private fun load() {
        runCatching {
            if (!storageFile.exists()) {
                return
            }

            val snapshot = json.decodeFromString<MarketplaceAuthSnapshot>(storageFile.readText())
            users = snapshot.users
            authAccounts = snapshot.authAccounts
            sessionUserId = snapshot.sessionUserId

            if (sessionUserId != null && users.none { it.id == sessionUserId }) {
                sessionUserId = null
            }
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
                    MarketplaceAuthSnapshot(
                        users = users,
                        authAccounts = authAccounts,
                        sessionUserId = sessionUserId
                    )
                )
            )
        }
    }
}
