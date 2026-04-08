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
