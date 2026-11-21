import SwiftUI
import WebKit

/// A locked-down WKWebView for one embedded post.
/// - Non-persistent data store: no cookies or history are kept.
/// - No autoplay: media needs a tap.
/// - Navigation away from the embed (links, pop-ups, new windows) is blocked.
struct EmbedWebView: UIViewRepresentable {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    let html: String
    let baseURL: URL
    @Binding var state: LoadState

    func makeCoordinator() -> Coordinator {
        Coordinator(baseURL: baseURL, state: $state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.loadHTMLString(html, baseURL: baseURL)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let baseURL: URL
        private var state: Binding<LoadState>

        init(baseURL: URL, state: Binding<LoadState>) {
            self.baseURL = baseURL
            self.state = state
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

            if isMainFrame {
                // Only our own local HTML document may load in the main frame.
                let isOwnDocument = url?.host == baseURL.host || url?.scheme == "about"
                decisionHandler(isOwnDocument ? .allow : .cancel)
                return
            }

            // Sub-frames: allow Instagram's embed iframe to load itself,
            // but block taps that would navigate it elsewhere.
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        /// Blocks target="_blank" links and window.open().
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.wrappedValue = .loaded
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            state.wrappedValue = .failed("The player stopped unexpectedly. Close it and try again.")
        }

        private func report(_ error: Error) {
            let nsError = error as NSError
            // Cancellations caused by our own navigation policy are expected.
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
            if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return } // Frame load interrupted by policy change
            state.wrappedValue = .failed(error.localizedDescription)
        }
    }
}
