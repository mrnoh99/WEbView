import Foundation

/// reveal.js `<section>` 슬라이드 하나.
struct Slide: Identifiable, Equatable {
    let id: UUID
    var sectionClass: String
    var innerHTML: String

    init(id: UUID = UUID(), sectionClass: String = "", innerHTML: String) {
        self.id = id
        self.sectionClass = sectionClass
        self.innerHTML = innerHTML
    }

    var previewText: String {
        innerHTML
            .replacingOccurrences(of: "<br>", with: " ")
            .replacingOccurrences(of: "<br/>", with: " ")
            .replacingOccurrences(of: "<br />", with: " ")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// reveal.js 형식 HTML 발표자료.
struct RevealSlideDocument: Equatable {
    var fileURL: URL
    var readAccessURL: URL
    var prefix: String
    var suffix: String
    var slides: [Slide]

    var displayName: String { fileURL.lastPathComponent }

    // MARK: - Load / Save

    static func load(from url: URL, readAccessURL: URL) throws -> RevealSlideDocument {
        let html = try String(contentsOf: url, encoding: .utf8)
        guard isRevealDeck(html) else {
            throw SlideDocumentError.notRevealFormat
        }

        let parsed = try parse(html: html)
        return RevealSlideDocument(
            fileURL: url,
            readAccessURL: readAccessURL,
            prefix: parsed.prefix,
            suffix: parsed.suffix,
            slides: parsed.slides
        )
    }

    static func isRevealDeck(_ html: String) -> Bool {
        html.range(of: #"<div\s+class="reveal""#, options: .regularExpression) != nil
            && html.range(of: "<section", options: .caseInsensitive) != nil
    }

    static func revealDeckURLs(in folder: URL) -> [URL] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .filter { ["html", "htm"].contains($0.pathExtension.lowercased()) }
            .filter { url in
                guard let html = try? String(contentsOf: url, encoding: .utf8) else { return false }
                return isRevealDeck(html)
            }
            .sorted { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
    }

    func write() throws {
        let html = renderedHTML()
        try html.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func renderedHTML() -> String {
        let body = slides.map { slide in
            let classAttr = slide.sectionClass.isEmpty ? "" : #" class="\#(slide.sectionClass)""#
            return "<section\(classAttr)>\(slide.innerHTML)</section>"
        }.joined()

        return prefix + body + suffix
    }

    /// 발표 미리보기용 HTML. `vendor/reveal.js` 를 인라인해 WKWebView 샌드박스 제한을 피한다.
    func presentationHTML() -> String {
        var html = renderedHTML()
        let bundleRoot = fileURL.deletingLastPathComponent()

        if let css = loadBundleText("vendor/reveal.js/reveal.min.css", root: bundleRoot) {
            html = replaceRevealStylesheet(in: html, withInlineCSS: css)
        }
        if let js = loadBundleText("vendor/reveal.js/reveal.min.js", root: bundleRoot) {
            html = replaceRevealScript(in: html, withInlineJS: js)
        }
        return html
    }

    private func loadBundleText(_ relativePath: String, root: URL) -> String? {
        let url = root.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func replaceRevealStylesheet(in html: String, withInlineCSS css: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<link[^>]+reveal\.min\.css[^>]*>"#,
            options: .caseInsensitive
        ) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(location: 0, length: (html as NSString).length),
            withTemplate: "<style>\(css)</style>"
        )
    }

    private func replaceRevealScript(in html: String, withInlineJS js: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<script[^>]+reveal\.min\.js[^>]*>\s*</script>"#,
            options: .caseInsensitive
        ) else { return html }
        let safeJS = js.replacingOccurrences(of: "</script>", with: "<\\/script>", options: .caseInsensitive)
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(location: 0, length: (html as NSString).length),
            withTemplate: "<script>\(safeJS)</script>"
        )
    }

    /// 미리보기 전 저장 후 파일 URL 로드에 쓸 읽기 허용 경로.
    var previewReadAccessURL: URL {
        let bundle = fileURL.deletingLastPathComponent().standardizedFileURL
        let access = readAccessURL.standardizedFileURL
        if bundle.path.hasPrefix(access.path + "/") || bundle.path == access.path {
            return access
        }
        return bundle
    }

    /// 현재 슬라이드만 미리보기용 HTML (1280×720 reveal.js 덱).
    func previewHTML(for index: Int) -> String {
        guard slides.indices.contains(index) else { return "" }
        let slide = slides[index]
        let classAttr = slide.sectionClass.isEmpty ? "" : #" class="\#(slide.sectionClass)""#
        let section = "<section\(classAttr)>\(slide.innerHTML)</section>"

        if let headEnd = prefix.range(of: "</head>", options: .caseInsensitive) {
            let head = String(prefix[..<headEnd.upperBound])
            let w = Int(SlideLayoutMetrics.deckWidth)
            let h = Int(SlideLayoutMetrics.deckHeight)
            return """
            \(head)
            <style>
            html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:#2a2a2a;}
            #viewport{display:flex;align-items:center;justify-content:center;width:100%;height:100%;}
            #deck{width:\(w)px;height:\(h)px;transform-origin:center center;overflow:hidden;background:#fff;}
            .reveal,.reveal .slides{width:100%!important;height:100%!important;}
            .reveal .slides section{top:0!important;transform:none!important;opacity:1!important;display:block!important;}
            </style>
            <body><div id="viewport"><div id="deck">
            <div class="reveal"><div class="slides">
            \(section)
            </div></div></div></div>
            <script>
            (function(){
              var deck=document.getElementById('deck'), vp=document.getElementById('viewport');
              function fit(){
                var s=Math.min(vp.clientWidth/\(w), vp.clientHeight/\(h));
                deck.style.transform='scale('+s+')';
              }
              fit(); window.addEventListener('resize', fit);
            })();
            </script>
            </body></html>
            """
        }

        return renderedHTML()
    }

    // MARK: - Parse

    private static func parse(html: String) throws -> (prefix: String, suffix: String, slides: [Slide]) {
        guard let firstSection = html.range(of: "<section", options: .caseInsensitive) else {
            throw SlideDocumentError.noSlides
        }

        let prefix = String(html[..<firstSection.lowerBound])
        let remainder = String(html[firstSection.lowerBound...])

        let slides = parseSections(from: remainder)
        guard !slides.isEmpty else { throw SlideDocumentError.noSlides }

        guard let lastClose = remainder.range(of: "</section>", options: .backwards) else {
            throw SlideDocumentError.noSlides
        }

        let suffix = String(remainder[lastClose.upperBound...])
        return (prefix, suffix, slides)
    }

    private static func parseSections(from html: String) -> [Slide] {
        let pattern = #"<section(?:\s+class="([^"]*)")?\s*>([\s\S]*?)</section>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        return matches.map { match in
            let classRange = match.range(at: 1)
            let innerRange = match.range(at: 2)
            let sectionClass = classRange.location != NSNotFound ? nsHTML.substring(with: classRange) : ""
            let inner = innerRange.location != NSNotFound ? nsHTML.substring(with: innerRange) : ""
            return Slide(sectionClass: sectionClass, innerHTML: inner)
        }
    }
}

enum SlideDocumentError: LocalizedError {
    case notRevealFormat
    case noSlides
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notRevealFormat:
            return "reveal.js 슬라이드 형식이 아닙니다."
        case .noSlides:
            return "슬라이드를 찾지 못했습니다."
        case .saveFailed:
            return "파일 저장에 실패했습니다."
        }
    }
}
