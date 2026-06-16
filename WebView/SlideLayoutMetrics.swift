import CoreGraphics

/// iPad Pro 11" (4세대) 및 reveal.js 덱(1280×720) 기준 레이아웃.
enum SlideLayoutMetrics {
    /// reveal.js `Reveal.initialize` 와 동일한 덱 크기.
    static let deckWidth: CGFloat = 1280
    static let deckHeight: CGFloat = 720
    static let aspectRatio: CGFloat = deckWidth / deckHeight

    /// iPad Pro 11" (4세대) 논리 포인트 — 가로 1194 × 세로 834.
    static let iPadPro11Landscape = CGSize(width: 1194, height: 834)

    static let filmstripWidth: CGFloat = 240
    static let canvasPadding: CGFloat = 20
    static let editorPanelHeight: CGFloat = 240
    static let bottomToolBarHeight: CGFloat = 52
    static let navigationChrome: CGFloat = 88

    static let thumbnailWidth: CGFloat = 200
    static var thumbnailHeight: CGFloat { thumbnailWidth / aspectRatio }

    /// 사용 가능 영역 안에 16:9 캔버스 크기를 계산한다.
    static func canvasSize(in container: CGSize, includesEditorPanel: Bool = true) -> CGSize {
        let editor = includesEditorPanel ? editorPanelHeight : 0
        let chrome = navigationChrome + bottomToolBarHeight
        let availW = max(0, container.width - filmstripWidth - canvasPadding * 2)
        let availH = max(0, container.height - editor - chrome - canvasPadding * 2)

        guard availW > 0, availH > 0 else { return .zero }

        let heightFromWidth = availW / aspectRatio
        if heightFromWidth <= availH {
            return CGSize(width: availW, height: heightFromWidth)
        }
        let widthFromHeight = availH * aspectRatio
        return CGSize(width: widthFromHeight, height: availH)
    }

    /// 세로 모드(iPad)용 캔버스.
    static func canvasSizePortrait(in container: CGSize, filmstripHeight: CGFloat = 112) -> CGSize {
        let chrome = navigationChrome + bottomToolBarHeight + 220
        let availW = max(0, container.width - canvasPadding * 2)
        let availH = max(0, container.height - filmstripHeight - chrome - canvasPadding * 2)

        guard availW > 0, availH > 0 else { return .zero }

        let heightFromWidth = availW / aspectRatio
        if heightFromWidth <= availH {
            return CGSize(width: availW, height: heightFromWidth)
        }
        let widthFromHeight = availH * aspectRatio
        return CGSize(width: widthFromHeight, height: availH)
    }
}
