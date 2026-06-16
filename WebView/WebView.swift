import SwiftUI
import WebKit

/// WKWebView 를 소유하고 로딩 상태를 SwiftUI 로 노출하는 모델.
/// WKWebView 는 Safari 와 동일한 WebKit 엔진을 사용하므로 렌더링 결과가 같다.
@MainActor
final class WebViewModel: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView

    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var pageTitle: String = ""
    @Published var currentURL: URL?
    @Published var errorMessage: String?

    private var observers: [NSKeyValueObservation] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Safari 처럼 데스크톱/모바일 자동 결정.
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        observers = [
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.canGoBack = wv.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.canGoForward = wv.canGoForward }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.isLoading = wv.isLoading }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.progress = wv.estimatedProgress }
            },
            webView.observe(\.title, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.pageTitle = wv.title ?? "" }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.currentURL = wv.url }
            },
        ]
    }

    /// 로컬 HTML 파일을 로드한다. 같은 폴더 전체에 읽기 권한을 줘야
    /// HTML 이 참조하는 CSS·JS·이미지 등 상대경로 리소스가 함께 로드된다.
    func load(fileURL: URL) {
        errorMessage = nil
        let directory = fileURL.deletingLastPathComponent()
        webView.loadFileURL(fileURL, allowingReadAccessTo: directory)
    }

    func reload() { webView.reload() }
    func stop() { webView.stopLoading() }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        errorMessage = error.localizedDescription
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // 사용자가 로딩을 취소한 경우는 무시.
        if (error as NSError).code == NSURLErrorCancelled { return }
        errorMessage = error.localizedDescription
    }
}

/// WKWebView 를 SwiftUI 에 끼워 넣는 래퍼.
struct WebView: UIViewRepresentable {
    let model: WebViewModel

    func makeUIView(context: Context) -> WKWebView { model.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// 공유 시트(다른 앱으로 보내기 / 저장).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
