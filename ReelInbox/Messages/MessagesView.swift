import SwiftUI
import WebKit

/// Instagram Direct Messages, and nothing else.
struct MessagesView: View {
    @Environment(InstagramWebSession.self) private var session

    var body: some View {
        NavigationStack {
            WebViewContainer(webView: session.webView)
                .background(Theme.background)
                .overlay(alignment: .bottom) {
                    if let toast = session.toast {
                        Text(toast)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5))
                            .padding(.bottom, 12)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: session.toast)
                .navigationTitle("Messages")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            session.goBack()
                        } label: {
                            Label("Back", systemImage: "chevron.backward")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            session.goToInbox()
                        } label: {
                            Label("All Chats", systemImage: "bubble.left.and.bubble.right")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            session.reload()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                    }
                }
                .onAppear {
                    session.startIfNeeded()
                }
        }
    }
}

/// Hosts an existing WKWebView (owned elsewhere) in SwiftUI.
struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
