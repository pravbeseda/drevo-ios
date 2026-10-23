import DrevoKit
import SwiftUI
import WebKit

/// The web view showing `model`'s page. A new one, as after the split view collapses or expands, resumes the page at
/// its last scroll; links go to the model, and the page's scroll reports come back to it.
struct ArticleWebView: UIViewRepresentable {
    let model: ArticleModel
    /// Passed in rather than read in `updateUIView`, so that SwiftUI updates the web view when it changes.
    let pageID: Int
    let jump: AnchorJump?
    let zoom: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // iPad's default desktop mode fits the page to the width, which undoes the text zoom.
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.userContentController.add(context.coordinator, name: ArticleHtmlBuilder.messageHandler)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isFindInteractionEnabled = true
        // The stylesheets leave the page background to the app, so it follows the system appearance.
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.openURL = context.environment.openURL
        if coordinator.zoom != zoom {
            coordinator.zoom = zoom
            // Every page to come gets it before its load script restores the scroll; the page shown, at once.
            let script = ArticleHtmlBuilder.zoomScript(zoom)
            let scripts = webView.configuration.userContentController
            scripts.removeAllUserScripts()
            scripts.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            webView.evaluateJavaScript(script)
        }
        if coordinator.requestedPageID != pageID, let page = model.resumedPage() {
            coordinator.requestedPageID = pageID
            coordinator.pendingLoad = webView.loadHTMLString(page.html, baseURL: model.baseURL)
        }
        if let jump, jump != coordinator.lastJump {
            coordinator.lastJump = jump
            webView.evaluateJavaScript(ArticleHtmlBuilder.jumpScript(to: jump.anchor))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let model: ArticleModel
        var openURL: OpenURLAction?
        var requestedPageID: Int?
        var pendingLoad: WKNavigation?
        var lastJump: AnchorJump?
        var zoom: Double?
        /// The page whose document is in the web view: the previous one keeps reporting scrolls until the next one
        /// commits, and those reports must not count for the next.
        private var committedPageID: Int?

        init(model: ArticleModel) {
            self.model = model
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            guard navigation == pendingLoad else { return }
            committedPageID = requestedPageID
            pendingLoad = nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async
            -> WKNavigationActionPolicy
        {
            // Loading the page itself and the scripts' anchor jumps are not the reader's taps.
            guard action.navigationType == .linkActivated, let url = action.request.url else { return .allow }
            switch await model.decide(url) {
            case .allow:
                return .allow
            case .cancel:
                return .cancel
            case .openExternally(let url):
                openURL?(url)
                return .cancel
            }
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], body["event"] as? String == "scroll",
                let position = body["position"] as? Double, let committedPageID
            else { return }
            model.recordScroll(position, onPage: committedPageID)
        }
    }
}
