import Foundation

/// The App Group shared by the main app and the Share Extension.
///
/// IMPORTANT: This string must exactly match the App Group listed in BOTH
/// `Config/ReelInbox.entitlements` and `Config/ShareExtension.entitlements`.
/// `configure.sh` rewrites all three places for you.
enum AppGroup {
    static let identifier = "group.com.reelinboxq4hn4.reelinbox"

    /// `nil` when the App Group entitlement is missing or misconfigured.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
