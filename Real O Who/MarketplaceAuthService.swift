import CryptoKit
import Foundation

nonisolated struct MarketplaceAuthRegistration: Sendable {
    var name: String
    var email: String
    var password: String
    var role: UserRole
    var suburb: String
}

nonisolated struct MarketplaceAuthSession: Sendable {
    var user: UserProfile
    var account: LocalAuthAccount
}

protocol MarketplaceAuthServing: Sendable {
    nonisolated func signIn(
        email: String,
        password: String,
        accounts: [LocalAuthAccount],
        users: [UserProfile]
    ) async throws -> MarketplaceAuthSession

    nonisolated func createAccount(
        registration: MarketplaceAuthRegistration,
        existingAccounts: [LocalAuthAccount]
    ) async throws -> MarketplaceAuthSession
}

nonisolated struct LocalMarketplaceAuthService: MarketplaceAuthServing, Sendable {
    nonisolated init() {}

    nonisolated func signIn(
        email: String,
        password: String,
        accounts: [LocalAuthAccount],
        users: [UserProfile]
    ) async throws -> MarketplaceAuthSession {
        let normalizedEmail = Self.normalizedEmail(email)
        guard Self.isValidEmail(normalizedEmail) else {
            throw MarketplaceAuthError.invalidEmail
        }

        guard let account = accounts.first(where: { $0.email == normalizedEmail }) else {
            throw MarketplaceAuthError.accountNotFound
        }

        guard let salt = Data(base64Encoded: account.passwordSaltBase64),
              let storedHash = Data(base64Encoded: account.passwordHashBase64) else {
            throw MarketplaceAuthError.accountUnavailable
        }

        let passwordHash = Self.hashedPassword(password, salt: salt)
        guard passwordHash == storedHash else {
            throw MarketplaceAuthError.incorrectPassword
        }

        guard let user = users.first(where: { $0.id == account.userID }) else {
            throw MarketplaceAuthError.accountUnavailable
        }

        var updatedAccount = account
        updatedAccount.lastSignedInAt = .now

        return MarketplaceAuthSession(user: user, account: updatedAccount)
    }

    nonisolated func createAccount(
        registration: MarketplaceAuthRegistration,
        existingAccounts: [LocalAuthAccount]
    ) async throws -> MarketplaceAuthSession {
        let trimmedName = registration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSuburb = registration.suburb.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = Self.normalizedEmail(registration.email)

        guard trimmedName.split(separator: " ").count >= 2 else {
            throw MarketplaceAuthError.invalidName
        }

        guard Self.isValidEmail(normalizedEmail) else {
            throw MarketplaceAuthError.invalidEmail
        }

        guard trimmedSuburb.count >= 2 else {
            throw MarketplaceAuthError.invalidSuburb
        }

        guard registration.password.count >= 8 else {
            throw MarketplaceAuthError.weakPassword
        }

        guard !existingAccounts.contains(where: { $0.email == normalizedEmail }) else {
            throw MarketplaceAuthError.emailTaken
        }

        let user = UserProfile(
            id: UUID(),
            name: trimmedName,
            role: registration.role,
            suburb: trimmedSuburb,
            headline: registration.role == .seller
                ? "Selling privately and keeping more of the final sale."
                : "Looking to buy directly from owners without agent friction.",
            verificationNote: registration.role == .seller
                ? "Private seller account created on this device"
                : "Buyer account created on this device",
            buyerStage: registration.role == .buyer ? .browsing : nil
        )

        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let passwordHash = Self.hashedPassword(registration.password, salt: salt)
        let account = LocalAuthAccount(
            id: UUID(),
            userID: user.id,
            email: normalizedEmail,
            passwordSaltBase64: salt.base64EncodedString(),
            passwordHashBase64: passwordHash.base64EncodedString(),
            createdAt: .now,
            lastSignedInAt: .now
        )

        return MarketplaceAuthSession(user: user, account: account)
    }

    private static func normalizedEmail(_ email: String) -> String {
        email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func isValidEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".")
    }

    private static func hashedPassword(_ password: String, salt: Data) -> Data {
        let combined = salt + Data(password.utf8)
        let digest = SHA256.hash(data: combined)
        return Data(digest)
    }
}
