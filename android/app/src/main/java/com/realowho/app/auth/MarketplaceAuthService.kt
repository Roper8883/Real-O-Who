package com.realowho.app.auth

import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import java.util.UUID

interface MarketplaceAuthService {
    suspend fun signIn(
        email: String,
        password: String,
        accounts: List<LocalAuthAccount>,
        users: List<MarketplaceUserProfile>
    ): MarketplaceAuthSession

    suspend fun createAccount(
        registration: MarketplaceAuthRegistration,
        existingAccounts: List<LocalAuthAccount>
    ): MarketplaceAuthSession
}

class LocalMarketplaceAuthService : MarketplaceAuthService {
    private val secureRandom = SecureRandom()

    override suspend fun signIn(
        email: String,
        password: String,
        accounts: List<LocalAuthAccount>,
        users: List<MarketplaceUserProfile>
    ): MarketplaceAuthSession {
        val normalizedEmail = normalizeEmail(email)
        if (!isValidEmail(normalizedEmail)) {
            throw MarketplaceAuthException.InvalidEmail
        }

        val account = accounts.firstOrNull { it.email == normalizedEmail }
            ?: throw MarketplaceAuthException.AccountNotFound

        val salt = decodeBase64(account.passwordSaltBase64)
            ?: throw MarketplaceAuthException.AccountUnavailable
        val storedHash = decodeBase64(account.passwordHashBase64)
            ?: throw MarketplaceAuthException.AccountUnavailable
        val passwordHash = hashPassword(password, salt)

        if (!passwordHash.contentEquals(storedHash)) {
            throw MarketplaceAuthException.IncorrectPassword
        }

        val user = users.firstOrNull { it.id == account.userId }
            ?: throw MarketplaceAuthException.AccountUnavailable

        return MarketplaceAuthSession(
            user = user,
            account = account.copy(lastSignedInAt = System.currentTimeMillis())
        )
    }

    override suspend fun createAccount(
        registration: MarketplaceAuthRegistration,
        existingAccounts: List<LocalAuthAccount>
    ): MarketplaceAuthSession {
        val trimmedName = registration.name.trim()
        val trimmedSuburb = registration.suburb.trim()
        val normalizedEmail = normalizeEmail(registration.email)

        if (trimmedName.split(Regex("\\s+")).filter { it.isNotBlank() }.size < 2) {
            throw MarketplaceAuthException.InvalidName
        }

        if (!isValidEmail(normalizedEmail)) {
            throw MarketplaceAuthException.InvalidEmail
        }

        if (trimmedSuburb.length < 2) {
            throw MarketplaceAuthException.InvalidSuburb
        }

        if (registration.password.length < 8) {
            throw MarketplaceAuthException.WeakPassword
        }

        if (existingAccounts.any { it.email == normalizedEmail }) {
            throw MarketplaceAuthException.EmailTaken
        }

        val now = System.currentTimeMillis()
        val user = MarketplaceUserProfile(
            id = UUID.randomUUID().toString(),
            name = trimmedName,
            role = registration.role,
            suburb = trimmedSuburb,
            headline = if (registration.role == UserRole.SELLER) {
                "Selling privately and keeping more of the final sale."
            } else {
                "Looking to buy directly from owners without agent friction."
            },
            verificationNote = if (registration.role == UserRole.SELLER) {
                "Private seller account created on this device"
            } else {
                "Buyer account created on this device"
            },
            buyerStage = if (registration.role == UserRole.BUYER) "browsing" else null,
            createdAt = now
        )

        val salt = ByteArray(16).also(secureRandom::nextBytes)
        val passwordHash = hashPassword(registration.password, salt)
        val account = LocalAuthAccount(
            id = UUID.randomUUID().toString(),
            userId = user.id,
            email = normalizedEmail,
            passwordSaltBase64 = Base64.getEncoder().encodeToString(salt),
            passwordHashBase64 = Base64.getEncoder().encodeToString(passwordHash),
            createdAt = now,
            lastSignedInAt = now
        )

        return MarketplaceAuthSession(user = user, account = account)
    }

    private fun normalizeEmail(email: String): String = email.trim().lowercase()

    private fun isValidEmail(email: String): Boolean = email.contains("@") && email.contains(".")

    private fun decodeBase64(value: String): ByteArray? {
        return runCatching { Base64.getDecoder().decode(value) }.getOrNull()
    }

    private fun hashPassword(password: String, salt: ByteArray): ByteArray {
        return MessageDigest
            .getInstance("SHA-256")
            .digest(salt + password.toByteArray(Charsets.UTF_8))
    }
}
