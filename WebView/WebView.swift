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

    /// 로컬 HTML 파일을 로드한다. `readAccessURL` 로 가져온 폴더 전체에 읽기 권한을 줘야
    /// HTML 이 참조하는 CSS·JS·이미지·다른 HTML 등 상대경로 리소스가 함께 로드된다.
    func load(fileURL: URL, readAccessURL: URL) {
        errorMessage = nil
        let file = fileURL.standardizedFileURL
        let bundle = file.deletingLastPathComponent()
        let access = Self.resolvedReadAccess(for: file, readAccessURL: readAccessURL)
        // 상대경로 리소스는 HTML 과 같은 bundle 폴더 기준.
        let readAccess = Self.pathContains(access, bundle) ? access : bundle
        webView.loadFileURL(file, allowingReadAccessTo: readAccess)
    }

    private static func resolvedReadAccess(for fileURL: URL, readAccessURL: URL) -> URL {
        let file = fileURL.standardizedFileURL
        let access = readAccessURL.standardizedFileURL
        let fileDir = file.deletingLastPathComponent()

        if pathContains(access, file) || pathContains(access, fileDir) {
            return access
        }
        return fileDir
    }

    private static func pathContains(_ ancestor: URL, _ descendant: URL) -> Bool {
        let base = ancestor.path
        let path = descendant.path
        return path == base || path.hasPrefix(base.hasSuffix("/") ? base : base + "/")
    }

    func reload() { webView.reload() }
    func stop() { webView.stopLoading() }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard shouldReportNavigationError(error) else { return }
        errorMessage = error.localizedDescription
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard shouldReportNavigationError(error) else { return }
        errorMessage = error.localizedDescription
    }

    private func shouldReportNavigationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return false }
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorFileDoesNotExist {
            return webView.url == nil
        }
        return true
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
