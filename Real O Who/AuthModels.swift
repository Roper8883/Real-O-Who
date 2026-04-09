import Foundation

nonisolated enum MarketplaceAuthError: LocalizedError, Sendable {
    case invalidName
    case invalidEmail
    case invalidSuburb
    case weakPassword
    case emailTaken
    case accountNotFound
    case incorrectPassword
    case accountUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Enter your full name to continue."
        case .invalidEmail:
            return "Enter a valid email address."
        case .invalidSuburb:
            return "Enter the suburb you live in or want to search."
        case .weakPassword:
            return "Use a password with at least 8 characters."
        case .emailTaken:
            return "That email is already in use on this device."
        case .accountNotFound:
            return "No local account was found for that email yet."
        case .incorrectPassword:
            return "That password does not match this local account."
        case .accountUnavailable:
            return "That account could not be loaded. Try creating it again."
        }
    }
}

nonisolated struct LocalAuthAccount: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var userID: UUID
    var email: String
    var passwordSaltBase64: String
    var passwordHashBase64: String
    var createdAt: Date
    var lastSignedInAt: Date?

    var redactedEmail: String {
        let parts = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return email }

        let localPart = parts[0]
        let domain = parts[1]

        if localPart.count <= 2 {
            return "\(localPart.prefix(1))••@\(domain)"
        }

        return "\(localPart.prefix(2))•••@\(domain)"
    }
}
