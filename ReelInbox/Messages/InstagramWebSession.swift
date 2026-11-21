import SwiftUI
import WebKit

/// Owns the single long-lived web view for the Messages tab, so chats stay
/// loaded when you switch tabs.
@MainActor
@Observable
final class InstagramWebSession {
    /// Short message shown when something was blocked.
    var toast: String?

    // `let` properties are never tracked by Observation.
    let webView: WKWebView
    private let delegate: InstagramWebDelegate
    @ObservationIgnored var onOpenMedia: ((InstagramLink) -> Void)?
    @ObservationIgnored var onOpenExternal: ((URL) -> Void)?
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init() {
        let delegate = InstagramWebDelegate()
        let script = InstagramWeb.guardScript(
            allowedPathPattern: InstagramWeb.messagesAllowedPathPattern,
            fallbackURL: InstagramWeb.inboxURL,
            interceptMedia: true,
            css: InstagramWeb.hideDistractionsCSS
        )
        let configuration = InstagramWeb.makeConfiguration(script: script, messageHandler: delegate)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = delegate
        webView.uiDelegate = delegate
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false

        self.delegate = delegate
        self.webView = webView
        delegate.session = self
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        goToInbox()
    }

    func goToInbox() {
        webView.load(URLRequest(url: InstagramWeb.inboxURL))
    }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            goToInbox()
        }
    }

    func reload() {
        if webView.url == nil {
            goToInbox()
        } else {
            webView.reload()
        }
    }

    /// Clears Instagram cookies and website data stored by this app.
    func logOut() {
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            Task { @MainActor in
                self?.goToInbox()
            }
        }
    }

    func handle(_ decision: InstagramWeb.Decision) {
        switch decision {
        case .allow:
            break
        case .redirectToInbox:
            goToInbox()
        case .openMedia(let link):
            onOpenMedia?(link)
        case .openExternal(let url):
            onOpenExternal?(url)
        case .block(let label):
            showToast("\(label) is blocked")
        }
    }

    private func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}

final class InstagramWebDelegate: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    weak var session: InstagramWebSession?

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        if !isMainFrame {
            // Sub-frames (login helpers, captchas, media) may load; they can't change the page.
            let scheme = url.scheme?.lowercased() ?? ""
            decisionHandler(["http", "https", "about", "blob", "data"].contains(scheme) ? .allow : .cancel)
            return
        }

        let decision = InstagramWeb.decide(url)
        if decision == .allow {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            session?.handle(decision)
        }
    }

    /// target="_blank" links and window.open(): apply the same rules, never open a new window.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            let decision = InstagramWeb.decide(url)
            if decision == .allow {
                webView.load(navigationAction.request)
            } else {
                session?.handle(decision)
            }
        }
        return nil
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String,
              let urlString = body["url"] as? String,
              let url = URL(string: urlString)
        else { return }

        switch type {
        case "media":
            if let link = InstagramLink.parse(url) {
                session?.handle(.openMedia(link))
            }
        case "blocked":
            session?.handle(.block(InstagramWeb.blockedLabel(for: url.path)))
        default:
            break
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}
