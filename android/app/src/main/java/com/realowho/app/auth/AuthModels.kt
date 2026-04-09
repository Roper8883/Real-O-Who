package com.realowho.app.auth

import kotlinx.serialization.Serializable

enum class UserRole(val title: String, val summary: String) {
    BUYER(
        title = "Buyer",
        summary = "Browse homes directly from owners and keep the conversation simple."
    ),
    SELLER(
        title = "Seller",
        summary = "List your home privately and keep more of the final sale."
    )
}

sealed class MarketplaceAuthException(message: String) : Exception(message) {
    object InvalidName : MarketplaceAuthException("Enter your full name to continue.")
    object InvalidEmail : MarketplaceAuthException("Enter a valid email address.")
    object InvalidSuburb : MarketplaceAuthException("Enter the suburb you live in or want to search.")
    object WeakPassword : MarketplaceAuthException("Use a password with at least 8 characters.")
    object EmailTaken : MarketplaceAuthException("That email is already in use on this device.")
    object AccountNotFound : MarketplaceAuthException("No local account was found for that email yet.")
    object IncorrectPassword : MarketplaceAuthException("That password does not match this local account.")
    object AccountUnavailable : MarketplaceAuthException("That account could not be loaded. Try again.")
    class BackendFailure(details: String) : MarketplaceAuthException(details)
}

@Serializable
data class MarketplaceUserProfile(
    val id: String,
    val name: String,
    val role: UserRole,
    val suburb: String,
    val headline: String,
    val verificationNote: String = "",
    val buyerStage: String? = null,
    val createdAt: Long
)

@Serializable
data class LocalAuthAccount(
    val id: String,
    val userId: String,
    val email: String,
    val passwordSaltBase64: String,
    val passwordHashBase64: String,
    val createdAt: Long,
    val lastSignedInAt: Long?
) {
    val redactedEmail: String
        get() {
            val parts = email.split("@", limit = 2)
            if (parts.size != 2) {
                return email
            }

            val localPart = parts[0]
            val domain = parts[1]
            return if (localPart.length <= 2) {
                "${localPart.take(1)}••@$domain"
            } else {
                "${localPart.take(2)}•••@$domain"
            }
        }
}

data class MarketplaceAuthRegistration(
    val name: String,
    val email: String,
    val password: String,
    val role: UserRole,
    val suburb: String
)

data class MarketplaceAuthSession(
    val user: MarketplaceUserProfile,
    val account: LocalAuthAccount
)

@Serializable
data class MarketplaceAuthSnapshot(
    val users: List<MarketplaceUserProfile> = emptyList(),
    val authAccounts: List<LocalAuthAccount> = emptyList(),
    val sessionUserId: String? = null
)
