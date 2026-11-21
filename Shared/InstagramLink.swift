import Foundation

/// A validated, normalized Instagram link.
///
/// Recognized forms (http or https, case-insensitive host and keywords):
///   instagram.com/reel/{code}            -> .reel
///   instagram.com/reels/{code}           -> .reel   (but NOT the bare /reels/ feed)
///   instagram.com/{username}/reel/{code} -> .reel
///   instagram.com/p/{code}               -> .post
///   instagram.com/{username}/p/{code}    -> .post
///   instagram.com/tv/{code}              -> .igtv
///   instagram.com/share/reel/{token}     -> .shareLink
///   instagram.com/share/p/{token}        -> .shareLink
///   instagram.com/share/{token}          -> .shareLink
/// Hosts: instagram.com, www.instagram.com, m.instagram.com, instagr.am, www.instagr.am
///
/// Query strings (e.g. the `igsh=` share-tracking parameter) and fragments are dropped.
struct InstagramLink: Equatable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case reel
        case post
        case igtv
        case shareLink

        var displayName: String {
            switch self {
            case .reel: return "Reel"
            case .post: return "Post"
            case .igtv: return "Video"
            case .shareLink: return "Shared link"
            }
        }
    }

    let kind: Kind
    /// The media shortcode. `nil` for `/share/...` links, whose token is not a shortcode.
    let shortcode: String?
    let canonicalURL: URL

    /// Short human-readable form, e.g. "instagram.com/reel/ABC123/".
    var displayString: String {
        canonicalURL.absoluteString.replacingOccurrences(of: "https://www.", with: "")
    }

    /// Meta's embed documentation lists /p/{shortcode}/ and /reel/{shortcode}/ URLs.
    var supportsEmbed: Bool {
        shortcode != nil && (kind == .reel || kind == .post)
    }

    // MARK: - Parsing

    private static let allowedHosts: Set<String> = [
        "instagram.com", "www.instagram.com", "m.instagram.com",
        "instagr.am", "www.instagr.am",
    ]

    /// First path segments that are Instagram sections, never usernames.
    private static let reservedFirstSegments: Set<String> = [
        "reel", "reels", "p", "tv", "share", "stories", "explore", "accounts",
        "direct", "about", "legal", "developer", "web", "api", "s",
    ]

    /// Second segments under /reels/ that are not shortcodes.
    private static let reservedReelsSegments: Set<String> = ["audio", "explore", "create"]

    static func parse(string: String) -> InstagramLink? {
        firstLink(in: string)
    }

    static func parse(_ url: URL) -> InstagramLink? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            let host = components.host?.lowercased(),
            allowedHosts.contains(host)
        else { return nil }

        let parts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        return parse(pathParts: parts)
    }

    /// Finds the first recognizable Instagram link in arbitrary text,
    /// e.g. "Check this out https://www.instagram.com/reel/ABC/?igsh=xyz".
    static func firstLink(in text: String) -> InstagramLink? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let link = parse(url) {
            return link
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        for match in detector.matches(in: trimmed, options: [], range: range) {
            if let url = match.url, let link = parse(url) {
                return link
            }
        }
        return nil
    }

    private static func parse(pathParts parts: [String]) -> InstagramLink? {
        let lower = parts.map { $0.lowercased() }

        switch parts.count {
        case 2:
            switch lower[0] {
            case "reel":
                return media(.reel, section: "reel", code: parts[1])
            case "reels":
                guard !reservedReelsSegments.contains(lower[1]) else { return nil }
                return media(.reel, section: "reel", code: parts[1])
            case "p":
                return media(.post, section: "p", code: parts[1])
            case "tv":
                return media(.igtv, section: "tv", code: parts[1])
            case "share":
                return share(path: [parts[1]])
            default:
                return nil
            }

        case 3:
            if lower[0] == "share" {
                switch lower[1] {
                case "reel": return share(path: ["reel", parts[2]])
                case "p": return share(path: ["p", parts[2]])
                default: return nil
                }
            }
            guard isUsername(parts[0]), !reservedFirstSegments.contains(lower[0]) else { return nil }
            switch lower[1] {
            case "reel": return media(.reel, section: "reel", code: parts[2])
            case "p": return media(.post, section: "p", code: parts[2])
            default: return nil
            }

        default:
            return nil
        }
    }

    private static func media(_ kind: Kind, section: String, code: String) -> InstagramLink? {
        guard isToken(code),
              let url = URL(string: "https://www.instagram.com/\(section)/\(code)/")
        else { return nil }
        return InstagramLink(kind: kind, shortcode: code, canonicalURL: url)
    }

    private static func share(path: [String]) -> InstagramLink? {
        guard let token = path.last, isToken(token),
              let url = URL(string: "https://www.instagram.com/share/\(path.joined(separator: "/"))/")
        else { return nil }
        return InstagramLink(kind: .shareLink, shortcode: nil, canonicalURL: url)
    }

    /// Shortcodes and share tokens use the URL-safe base64 alphabet.
    private static func isToken(_ value: String) -> Bool {
        guard (5...64).contains(value.count) else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "A"..."Z", "a"..."z", "0"..."9", "_", "-": return true
            default: return false
            }
        }
    }

    /// Instagram usernames: letters, digits, periods, underscores; max 30 characters.
    private static func isUsername(_ value: String) -> Bool {
        guard (1...30).contains(value.count) else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "A"..."Z", "a"..."z", "0"..."9", "_", ".": return true
            default: return false
            }
        }
    }
}
