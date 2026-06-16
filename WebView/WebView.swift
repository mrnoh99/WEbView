import SwiftUI
import WebKit

/// reveal.js 등 발표 슬라이드에서 키보드(←/→·스페이스) 입력을 받을 수 있게 한다.
final class PresentationWebView: WKWebView {
    override var canBecomeFirstResponder: Bool { true }

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        // reveal.js 가 자체 뷰포트를 쓰므로 WKWebView 스크롤과 충돌하지 않게 끈다.
        scrollView.isScrollEnabled = false
        scrollView.bounces = false
        scrollView.contentInsetAdjustmentBehavior = .never
        // 가로 스와이프를 브라우저 뒤로/앞으로 제스처가 가로채지 않게 끈다.
        allowsBackForwardNavigationGestures = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

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
    @Published var isRevealPresentation = false

    private var observers: [NSKeyValueObservation] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        webView = PresentationWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self

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
        isRevealPresentation = false
        let file = fileURL.standardizedFileURL
        let bundle = file.deletingLastPathComponent()
        let access = Self.resolvedReadAccess(for: file, readAccessURL: readAccessURL)
        // vendor/ 등 상대경로 리소스는 HTML 과 같은 bundle 폴더 기준.
        let readAccess = Self.pathContains(access, bundle) ? access : bundle
        webView.loadFileURL(file, allowingReadAccessTo: readAccess)
    }

    /// 메모리상 HTML 을 로드한다. 편집 미리보기처럼 file URL 샌드박스 문제를 피할 때 사용.
    func load(html: String, baseURL: URL) {
        errorMessage = nil
        isRevealPresentation = false
        webView.loadHTMLString(html, baseURL: baseURL.standardizedFileURL)
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

    /// reveal.js 슬라이드 이전. reveal 이 없으면 브라우저 뒤로.
    func slidePrevious() {
        webView.evaluateJavaScript(Self.slidePreviousJS) { [weak self] result, _ in
            guard let self else { return }
            Task { @MainActor in
                switch result as? String {
                case "first", "none":
                    self.goBack()
                default:
                    break
                }
            }
        }
    }

    /// reveal.js 슬라이드 다음. reveal 이 없으면 브라우저 앞으로.
    func slideNext() {
        webView.evaluateJavaScript(Self.slideNextJS) { [weak self] result, _ in
            guard let self else { return }
            Task { @MainActor in
                if result as? String == "none" { self.goForward() }
            }
        }
    }

    /// reveal.js 전체화면(가능한 경우)과 연동.
    func togglePresentationFullscreen(active: Bool) {
        let js = active ? Self.revealEnterFullscreenJS : Self.revealExitFullscreenJS
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorMessage = nil
        webView.becomeFirstResponder()
        detectRevealPresentation()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if !isRevealPresentation { detectRevealPresentation() }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard shouldReportNavigationError(error) else { return }
        errorMessage = error.localizedDescription
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard shouldReportNavigationError(error) else { return }
        errorMessage = error.localizedDescription
    }

    private func detectRevealPresentation() {
        webView.evaluateJavaScript(Self.revealStateJS) { [weak self] result, _ in
            Task { @MainActor in
                switch result as? String {
                case "ready":
                    self?.isRevealPresentation = true
                case "missing":
                    self?.isRevealPresentation = false
                    self?.errorMessage =
                        "슬라이드 엔진(reveal.js)을 불러오지 못했습니다. "
                        + "AuSom-PU 폴더에 vendor/reveal.js 가 있는지 확인하세요."
                default:
                    self?.isRevealPresentation = false
                }
            }
        }
    }

    private func shouldReportNavigationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return false }
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorFileDoesNotExist {
            return webView.url == nil
        }
        return true
    }

    private static let revealStateJS = """
        (function() {
            if (typeof Reveal !== 'undefined' && Reveal.isReady && Reveal.isReady()) return 'ready';
            if (document.querySelector('.reveal')) return 'missing';
            return 'none';
        })()
        """

    private static let slidePreviousJS = """
        (function() {
            if (typeof Reveal !== 'undefined' && Reveal.isReady && Reveal.isReady()) {
                if (Reveal.isFirstSlide()) return 'first';
                Reveal.prev();
                return 'reveal';
            }
            return 'none';
        })()
        """

    private static let slideNextJS = """
        (function() {
            if (typeof Reveal !== 'undefined' && Reveal.isReady && Reveal.isReady()) {
                Reveal.next();
                return 'reveal';
            }
            return 'none';
        })()
        """

    private static let revealEnterFullscreenJS = """
        (function() {
            if (typeof Reveal !== 'undefined' && Reveal.isReady && Reveal.isReady() && !Reveal.isFullscreen()) {
                Reveal.toggleFullscreen();
            }
        })()
        """

    private static let revealExitFullscreenJS = """
        (function() {
            if (typeof Reveal !== 'undefined' && Reveal.isReady && Reveal.isReady() && Reveal.isFullscreen()) {
                Reveal.toggleFullscreen();
            }
        })()
        """
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
