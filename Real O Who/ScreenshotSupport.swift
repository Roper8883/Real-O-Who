import Foundation

struct AppLaunchConfiguration {
    static let shared = AppLaunchConfiguration()

    let isScreenshotMode: Bool
    let initialTabRawValue: String?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        isScreenshotMode = arguments.contains("--screenshot-mode")

        if let tabIndex = arguments.firstIndex(of: "--tab"), arguments.indices.contains(tabIndex + 1) {
            initialTabRawValue = arguments[tabIndex + 1]
        } else {
            initialTabRawValue = nil
        }
    }
}

enum LegalWorkspaceDeepLink {
    static let scheme = "realowho"
    static let host = "legal-workspace"
    static let codeQueryItemName = "code"

    static func url(for inviteCode: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: codeQueryItemName, value: inviteCode)]
        return components.url
    }

    static func inviteCode(from url: URL) -> String? {
        guard url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame,
              url.host?.caseInsensitiveCompare(host) == .orderedSame else {
            return nil
        }

        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == codeQueryItemName })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}
