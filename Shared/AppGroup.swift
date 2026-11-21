import Foundation

/// The App Group shared by the main app and the Share Extension.
///
/// `configuredIdentifier` must match the App Group in BOTH
/// `Config/ReelInbox.entitlements` and `Config/ShareExtension.entitlements`
/// (`configure.sh` rewrites all three places).
///
/// Re-signing tools (Sideloadly, AltStore, ...) may rename or drop App Groups
/// when they sign with a free Apple ID. So at runtime we try, in order:
///   1. the configured identifier,
///   2. groups listed under `ALTAppGroups` in Info.plist (added by some tools),
///   3. groups listed in the app's embedded provisioning profile.
/// The first one iOS actually grants access to wins. If none works, the
/// Share Extension falls back to `PasteboardHandoff`.
enum AppGroup {
    static let configuredIdentifier = "group.com.reelinboxq4hn4.reelinbox"

    /// The App Group this process can really use, or `nil` if none is available.
    static let resolvedIdentifier: String? = resolve()

    /// For display and error messages.
    static var identifier: String {
        resolvedIdentifier ?? configuredIdentifier
    }

    static var isRenamed: Bool {
        resolvedIdentifier != nil && resolvedIdentifier != configuredIdentifier
    }

    /// `nil` when no App Group is available to this process.
    static var containerURL: URL? {
        resolvedIdentifier.flatMap {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    }

    static func candidateIdentifiers() -> [String] {
        var candidates = [configuredIdentifier]
        if let altGroups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
            candidates += altGroups.sorted()
        }
        // Prefer groups that look like ours, then any others, in a stable order
        // so the app and the extension pick the same one.
        let profileGroups = ProvisioningProfile.appGroups().sorted()
        candidates += profileGroups.filter { $0.localizedCaseInsensitiveContains("reelinbox") }
        candidates += profileGroups.filter { !$0.localizedCaseInsensitiveContains("reelinbox") }

        var seen = Set<String>()
        return candidates.filter { !$0.isEmpty && !$0.contains("*") && seen.insert($0).inserted }
    }

    private static func resolve() -> String? {
        candidateIdentifiers().first { identifier in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
        }
    }
}

/// Reads the `embedded.mobileprovision` file that ships inside every
/// development-signed app (and extension). It is a CMS-signed envelope around
/// a plain XML property list, so the XML part can be cut out and parsed.
enum ProvisioningProfile {
    static func appGroups() -> [String] {
        guard let entitlements = entitlements() else { return [] }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }

    static func entitlements() -> [String: Any]? {
        guard
            let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
            let data = try? Data(contentsOf: url),
            let start = data.range(of: Data("<?xml".utf8)),
            let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }

        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard
            let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
            let dictionary = plist as? [String: Any]
        else { return nil }
        return dictionary["Entitlements"] as? [String: Any]
    }
}
