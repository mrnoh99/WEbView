import Foundation

/// reveal.js `<section>` 슬라이드 하나.
struct Slide: Identifiable, Equatable {
    let id: UUID
    /// `<section` 와 닫는 `>` 사이의 원본 속성 문자열(선행 공백 포함).
    /// 예: ` class="title" data-background="#fff" id="intro"`.
    /// class 외의 속성도 모두 보존해 저장 시 손실을 막는다.
    var attributes: String
    var innerHTML: String
    /// 이 섹션 바로 앞(이전 섹션과의 사이)의 원본 공백·주석 등. 첫 슬라이드는 ""(prefix 가 포함).
    /// 새로 추가된 슬라이드는 "" → 렌더링 시 덱의 기본 간격으로 채운다.
    var gapBefore: String

    init(id: UUID = UUID(), attributes: String = "", innerHTML: String, gapBefore: String = "") {
        self.id = id
        self.attributes = attributes
        self.innerHTML = innerHTML
        self.gapBefore = gapBefore
    }

    /// 새 슬라이드를 class 만 지정해 만들 때(에디터의 ‘추가’).
    init(id: UUID = UUID(), sectionClass: String, innerHTML: String) {
        self.id = id
        self.innerHTML = innerHTML
        self.gapBefore = ""
        self.attributes = sectionClass.isEmpty ? "" : #" class="\#(sectionClass)""#
    }

    /// reveal.js `class` 속성. 에디터의 ‘스타일’ 필드와 연결되며, 나머지 속성은 보존된다.
    var sectionClass: String {
        get { Slide.classValue(in: attributes) }
        set { attributes = Slide.setting(class: newValue, in: attributes) }
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

    // MARK: - class 속성 도우미

    static func classValue(in attributes: String) -> String {
        for pattern in [#"class\s*=\s*"([^"]*)""#, #"class\s*=\s*'([^']*)'"#] {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = attributes as NSString
            if let m = re.firstMatch(in: attributes, range: NSRange(location: 0, length: ns.length)),
               m.numberOfRanges > 1 {
                return ns.substring(with: m.range(at: 1))
            }
        }
        return ""
    }

    /// 다른 속성은 그대로 두고 class 값만 교체/삽입/삭제한다.
    static func setting(class newValue: String, in attributes: String) -> String {
        if let range = firstClassRange(in: attributes) {
            let replacement = newValue.isEmpty ? "" : #" class="\#(newValue)""#
            return attributes.replacingCharacters(in: range, with: replacement)
        }
        if newValue.isEmpty { return attributes }
        return attributes + #" class="\#(newValue)""#
    }

    /// 선행 공백을 포함한 `class="..."` 의 범위(없으면 nil).
    private static func firstClassRange(in attributes: String) -> Range<String.Index>? {
        for pattern in [#"\s*class\s*=\s*"[^"]*""#, #"\s*class\s*=\s*'[^']*'"#] {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = attributes as NSString
            if let m = re.firstMatch(in: attributes, range: NSRange(location: 0, length: ns.length)),
               let r = Range(m.range, in: attributes) {
                return r
            }
        }
        return nil
    }
}

/// reveal.js 형식 HTML 발표자료.
struct RevealSlideDocument: Equatable {
    var fileURL: URL
    var readAccessURL: URL
    var prefix: String
    var suffix: String
    var slides: [Slide]
    /// 섹션 사이 기본 간격(추가된 슬라이드의 gapBefore 가 비었을 때 사용).
    var defaultGap: String = "\n"

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
            slides: parsed.slides,
            defaultGap: parsed.defaultGap
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
        var body = ""
        for (index, slide) in slides.enumerated() {
            if index > 0 {
                body += slide.gapBefore.isEmpty ? defaultGap : slide.gapBefore
            }
            body += "<section\(slide.attributes)>\(slide.innerHTML)</section>"
        }
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
        let section = "<section\(slide.attributes)>\(slide.innerHTML)</section>"

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

    private struct ParseResult {
        let prefix: String
        let suffix: String
        let slides: [Slide]
        let defaultGap: String
    }

    /// 최상위 `<section>` 의 위치 정보. 깊이를 추적해 중첩(세로 슬라이드) 섹션은 건너뛴다.
    private struct SectionSpan {
        let tagStart: String.Index    // '<' 위치
        let attrStart: String.Index   // "<section" 직후 (속성 시작)
        let attrEnd: String.Index     // 여는 태그를 닫는 '>' 위치
        let contentStart: String.Index
        let contentEnd: String.Index  // 닫는 "</section>" 의 '<' 위치
        let end: String.Index         // "</section>" 직후
    }

    private static func parse(html: String) throws -> ParseResult {
        let spans = topLevelSectionSpans(in: html)
        guard let first = spans.first, let last = spans.last else {
            throw SlideDocumentError.noSlides
        }

        let prefix = String(html[html.startIndex..<first.tagStart])
        let suffix = String(html[last.end..<html.endIndex])

        var slides: [Slide] = []
        for (index, span) in spans.enumerated() {
            let gapBefore = index == 0
                ? ""
                : String(html[spans[index - 1].end..<span.tagStart])
            let attributes = String(html[span.attrStart..<span.attrEnd])
            let inner = String(html[span.contentStart..<span.contentEnd])
            slides.append(Slide(attributes: attributes, innerHTML: inner, gapBefore: gapBefore))
        }

        // 섹션 사이 대표 간격(추가 슬라이드에 재사용). 없으면 줄바꿈.
        let defaultGap = slides.dropFirst().first(where: { !$0.gapBefore.isEmpty })?.gapBefore ?? "\n"

        return ParseResult(prefix: prefix, suffix: suffix, slides: slides, defaultGap: defaultGap)
    }

    /// 깊이·인용부호를 인식해 최상위 `<section>…</section>` 구간만 수집한다.
    /// 중첩 `<section>`(reveal.js 세로 스택)은 내부 콘텐츠로 그대로 보존된다.
    private static func topLevelSectionSpans(in html: String) -> [SectionSpan] {
        var spans: [SectionSpan] = []
        var depth = 0
        let end = html.endIndex

        var openTagStart: String.Index?
        var openAttrStart: String.Index?
        var openAttrEnd: String.Index?
        var openContentStart: String.Index?

        func hasPrefix(_ token: String, at idx: String.Index) -> Bool {
            guard let upper = html.index(idx, offsetBy: token.count, limitedBy: end) else { return false }
            return html[idx..<upper].lowercased() == token
        }

        // "<section" 뒤가 태그 경계(공백/'>'/'/')인지 — "<sectionish" 오탐 방지.
        func isSectionOpen(at idx: String.Index) -> Bool {
            guard hasPrefix("<section", at: idx) else { return false }
            guard let after = html.index(idx, offsetBy: 8, limitedBy: end), after < end else { return true }
            return " \t\n\r>/".contains(html[after])
        }

        // 여는 태그를 닫는 '>' 를 인용부호를 건너뛰며 찾는다.
        func tagEnd(from start: String.Index) -> String.Index? {
            var j = start
            var quote: Character?
            while j < end {
                let ch = html[j]
                if let q = quote {
                    if ch == q { quote = nil }
                } else if ch == "\"" || ch == "'" {
                    quote = ch
                } else if ch == ">" {
                    return j
                }
                j = html.index(after: j)
            }
            return nil
        }

        var i = html.startIndex
        while i < end {
            if html[i] == "<" {
                if hasPrefix("</section>", at: i) {
                    let closeEnd = html.index(i, offsetBy: 10)
                    if depth > 0 {
                        depth -= 1
                        if depth == 0,
                           let ts = openTagStart, let asx = openAttrStart,
                           let ae = openAttrEnd, let cs = openContentStart {
                            spans.append(SectionSpan(
                                tagStart: ts, attrStart: asx, attrEnd: ae,
                                contentStart: cs, contentEnd: i, end: closeEnd
                            ))
                            openTagStart = nil; openAttrStart = nil
                            openAttrEnd = nil; openContentStart = nil
                        }
                    }
                    i = closeEnd
                    continue
                } else if isSectionOpen(at: i) {
                    let afterName = html.index(i, offsetBy: 8)
                    guard let gt = tagEnd(from: afterName) else { break } // 깨진 태그 — 중단
                    let selfClosing = html[html.index(before: gt)] == "/"
                    let afterGt = html.index(after: gt)

                    if selfClosing {
                        // 빈 자가닫힘 섹션. 최상위면 빈 슬라이드로 보존.
                        if depth == 0 {
                            let attrEnd = html.index(before: gt) // 끝의 '/' 제외
                            spans.append(SectionSpan(
                                tagStart: i, attrStart: afterName, attrEnd: attrEnd,
                                contentStart: afterGt, contentEnd: afterGt, end: afterGt
                            ))
                        }
                    } else {
                        if depth == 0 {
                            openTagStart = i
                            openAttrStart = afterName
                            openAttrEnd = gt
                            openContentStart = afterGt
                        }
                        depth += 1
                    }
                    i = afterGt
                    continue
                }
            }
            i = html.index(after: i)
        }

        return spans
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
