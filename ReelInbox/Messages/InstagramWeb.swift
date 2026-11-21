import Foundation
import WebKit

/// Rules for the Messages tab: Instagram's official website, limited to Direct
/// Messages and the pages needed to log in. Everything else (feed, Reels,
/// Explore, Stories, profiles) is blocked twice:
///   1. natively, for real page loads (`decide(_:)`), and
///   2. by an injected script for in-page (single-page-app) route changes and taps.
@MainActor
enum InstagramWeb {
    static let inboxURL = URL(string: "https://www.instagram.com/direct/inbox/")!

    /// Makes WKWebView's user agent match Safari on iPhone, so instagram.com
    /// serves its normal mobile site.
    static let userAgentSuffix = "Version/18.0 Mobile/15E148 Safari/604.1"

    static let instagramHosts: Set<String> = ["instagram.com", "www.instagram.com", "m.instagram.com"]

    /// Hosts Instagram may use during login (Accounts Center, "Log in with Facebook").
    static let loginHelperHosts: Set<String> = [
        "accountscenter.instagram.com",
        "facebook.com", "www.facebook.com", "m.facebook.com", "web.facebook.com",
    ]

    /// Paths allowed in the Messages tab. Keep in sync with the script (it receives this string).
    static let messagesAllowedPathPattern = "^/(direct|accounts|challenge|two_factor|auth_platform|oauth|session|emails)(/|$)"

    /// Hides navigation to distracting sections. Best-effort: Instagram can change its markup,
    /// but blocked pages stay blocked by the navigation rules even if an icon reappears.
    static let hideDistractionsCSS = """
    a[href="/"], a[href="/reels/"], a[href^="/reels/?"], a[href="/explore/"], a[href^="/explore/"],
    a:has(svg[aria-label="Reels"]), a:has(svg[aria-label="Explore"]), a:has(svg[aria-label="Home"]),
    a:has(svg[aria-label="Search"]), a:has(svg[aria-label="Search & Explore"]) {
      display: none !important;
    }
    """

    enum Decision: Equatable {
        case allow
        case redirectToInbox
        case openMedia(InstagramLink)
        case openExternal(URL)
        case block(String)
    }

    /// Decision for a main-frame navigation in the Messages tab.
    static func decide(_ url: URL) -> Decision {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased()
        else { return .block("This link") }

        if ["about", "blob", "data"].contains(scheme) { return .allow }
        guard scheme == "https" || scheme == "http" else {
            // instagram://, itms-apps://, etc. Never leave to another app.
            return .block("Opening other apps")
        }

        let host = components.host?.lowercased() ?? ""

        // Instagram's outbound link shim: l.instagram.com/?u=<destination>
        if host == "l.instagram.com" {
            if let target = components.queryItems?.first(where: { $0.name == "u" })?.value,
               let destination = URL(string: target) {
                return .openExternal(destination)
            }
            return .block("This link")
        }

        if loginHelperHosts.contains(host) { return .allow }
        guard instagramHosts.contains(host) else { return .openExternal(url) }

        let path = components.path.isEmpty ? "/" : components.path
        if path == "/" { return .redirectToInbox }
        if let link = InstagramLink.parse(url) { return .openMedia(link) }
        if path.range(of: messagesAllowedPathPattern, options: .regularExpression) != nil { return .allow }
        return .block(blockedLabel(for: path))
    }

    static func blockedLabel(for path: String) -> String {
        let first = path.split(separator: "/").first.map { $0.lowercased() } ?? ""
        switch first {
        case "": return "The feed"
        case "reels": return "Reels"
        case "explore": return "Explore"
        case "stories": return "Stories"
        default: return "This page"
        }
    }

    // MARK: - Web view setup

    static func makeConfiguration(script: String, messageHandler: WKScriptMessageHandler?) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        // Persistent store on this device only, so you stay logged in.
        configuration.websiteDataStore = .default()
        configuration.applicationNameForUserAgent = userAgentSuffix
        configuration.allowsInlineMediaPlayback = true
        // No autoplay anywhere: videos start only when you tap them.
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        if let messageHandler {
            controller.add(WeakScriptMessageHandler(messageHandler), name: "reelInbox")
        }
        configuration.userContentController = controller
        return configuration
    }

    /// The in-page guard. It does three things:
    ///   - intercepts taps on links to pages outside `allowedPathPattern`
    ///   - catches in-page route changes (history.pushState etc.) to such pages and undoes them
    ///   - injects `css` to hide distracting navigation
    /// When `interceptMedia` is true, taps and routes to a reel or post are reported as
    /// `{type: "media"}` so the app can open its locked single-reel viewer.
    static func guardScript(allowedPathPattern: String, fallbackURL: URL, interceptMedia: Bool, css: String) -> String {
        let allowed = jsString(allowedPathPattern)
        let fallback = jsString(fallbackURL.absoluteString)
        let styles = jsString(css)
        let intercept = interceptMedia ? "true" : "false"
        return #"""
        (function () {
          if (window.__reelInboxGuard) { return; }
          window.__reelInboxGuard = true;

          var ALLOWED = new RegExp(\#(allowed));
          var MEDIA = /^\/(?:[A-Za-z0-9._]+\/)?(?:reel|reels|p|tv)\/[A-Za-z0-9_-]{5,64}\/?$/;
          var FALLBACK = \#(fallback);
          var INTERCEPT_MEDIA = \#(intercept);
          var CSS = \#(styles);

          function post(message) {
            try { window.webkit.messageHandlers.reelInbox.postMessage(message); } catch (e) {}
          }
          function isAllowed(path) { return ALLOWED.test(path); }
          function isInstagramHost(host) { return /(^|\.)instagram\.com$/i.test(host); }

          var lastAllowed = isAllowed(location.pathname) ? location.href : FALLBACK;
          var lastFix = 0;

          function evaluate() {
            var path = location.pathname;
            if (isAllowed(path)) { lastAllowed = location.href; return; }
            var now = Date.now();
            if (now - lastFix < 1500) { return; }
            lastFix = now;
            if (path === "/") {
              // Home feed (e.g. right after logging in): go to the chats instead.
              location.replace(FALLBACK);
              return;
            }
            if (INTERCEPT_MEDIA && MEDIA.test(path)) {
              post({ type: "media", url: location.href });
            } else {
              post({ type: "blocked", url: location.href });
            }
            location.replace(lastAllowed);
          }

          ["pushState", "replaceState"].forEach(function (name) {
            var original = history[name];
            history[name] = function () {
              var result = original.apply(this, arguments);
              setTimeout(evaluate, 0);
              return result;
            };
          });
          window.addEventListener("popstate", evaluate);
          setInterval(evaluate, 800);

          document.addEventListener("click", function (event) {
            var target = event.target;
            var anchor = target && target.closest ? target.closest("a[href]") : null;
            if (!anchor) { return; }
            var url;
            try { url = new URL(anchor.getAttribute("href"), location.href); } catch (e) { return; }
            if (!isInstagramHost(url.hostname)) { return; }
            if (isAllowed(url.pathname)) { return; }
            event.preventDefault();
            event.stopImmediatePropagation();
            if (INTERCEPT_MEDIA && MEDIA.test(url.pathname)) {
              post({ type: "media", url: url.href });
            } else {
              post({ type: "blocked", url: url.href });
            }
          }, true);

          function addStyle() {
            if (!CSS) { return; }
            var style = document.createElement("style");
            style.textContent = CSS;
            (document.head || document.documentElement).appendChild(style);
          }
          if (document.documentElement) { addStyle(); }
          else { document.addEventListener("DOMContentLoaded", addStyle); }
        })();
        """#
    }

    /// Encodes a Swift string as a JavaScript string literal (JSON-escaped).
    static func jsString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let literal = String(data: data, encoding: .utf8)
        else { return "\"\"" }
        return literal
    }
}

/// WKUserContentController retains its handlers strongly; this breaks the cycle.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
