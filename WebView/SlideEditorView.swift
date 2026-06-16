import SwiftUI
import WebKit

/// 편집 중인 슬라이드 미리보기.
struct SlidePreviewWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}

/// PowerPoint 스타일 reveal.js 슬라이드 편집 화면.
struct SlideEditorView: View {
    @EnvironmentObject var store: RecentsStore
    @StateObject private var model: SlideEditorViewModel
    @State private var showPreview = false
    @State private var editMode: EditorPanel = .content
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(document: RevealSlideDocument) {
        _model = StateObject(wrappedValue: SlideEditorViewModel(document: document))
    }

    enum EditorPanel: String, CaseIterable {
        case content = "내용"
        case html = "HTML"
        case style = "스타일"
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Group {
                    if geometry.size.width > geometry.size.height {
                        iPadLandscapeLayout(containerSize: geometry.size)
                    } else {
                        iPadPortraitLayout(containerSize: geometry.size)
                    }
                }
            }
            .navigationTitle(model.document.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { editorToolbar }
        }
        .fullScreenCover(isPresented: $showPreview) {
            SlideDeckPreviewView(editorModel: model)
        }
        .alert("알림", isPresented: statusBinding) {
            Button("확인", role: .cancel) {
                model.statusMessage = nil
            }
        } message: {
            if let message = model.statusMessage {
                Text(message)
            }
        }
    }

    // MARK: - Layout (iPad Pro 11" 4세대 · 1194×834 landscape)

    private func iPadLandscapeLayout(containerSize: CGSize) -> some View {
        HStack(spacing: 0) {
            slideFilmstrip
                .frame(width: SlideLayoutMetrics.filmstripWidth)
            Divider()
            VStack(spacing: 0) {
                slideCanvas(containerSize: containerSize, landscape: true)
                    .frame(maxHeight: .infinity)
                Divider()
                editorPanel
                    .frame(height: SlideLayoutMetrics.editorPanelHeight)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            slideToolBar
                .frame(height: SlideLayoutMetrics.bottomToolBarHeight)
        }
    }

    private func iPadPortraitLayout(containerSize: CGSize) -> some View {
        VStack(spacing: 0) {
            slideFilmstripHorizontal
                .frame(height: SlideLayoutMetrics.thumbnailHeight + 24)
            Divider()
            slideCanvas(containerSize: containerSize, landscape: false)
                .frame(maxHeight: .infinity)
            Divider()
            editorPanel
                .frame(height: 200)
            slideToolBar
                .frame(height: SlideLayoutMetrics.bottomToolBarHeight)
        }
    }

    // MARK: - Filmstrip (legacy removed)

    private var slideFilmstrip: some View {
        VStack(spacing: 0) {
            List {
                ForEach(Array(model.document.slides.enumerated()), id: \.element.id) { index, slide in
                    SlideThumbnailRow(index: index, slide: slide, isSelected: index == model.selectedIndex)
                        .contentShape(Rectangle())
                        .onTapGesture { model.selectSlide(at: index) }
                }
                .onMove { source, dest in model.moveSlide(from: source, to: dest) }
            }
            .listStyle(.plain)

            Button {
                model.addSlide()
            } label: {
                Label("슬라이드 추가", systemImage: "plus.rectangle.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }

    private var slideFilmstripHorizontal: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(model.document.slides.enumerated()), id: \.element.id) { index, slide in
                    SlideThumbnailCard(index: index, slide: slide, isSelected: index == model.selectedIndex)
                        .onTapGesture { model.selectSlide(at: index) }
                }
                Button {
                    model.addSlide()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("추가")
                            .font(.caption2)
                    }
                    .frame(
                        width: SlideLayoutMetrics.thumbnailWidth * 0.55,
                        height: SlideLayoutMetrics.thumbnailHeight * 0.55
                    )
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SlideLayoutMetrics.canvasPadding)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Canvas

    private func slideCanvas(containerSize: CGSize, landscape: Bool) -> some View {
        let canvasSize = landscape
            ? SlideLayoutMetrics.canvasSize(in: containerSize)
            : SlideLayoutMetrics.canvasSizePortrait(in: containerSize)

        return ZStack {
            Color(.systemGroupedBackground)

            SlidePreviewWebView(
                html: model.document.previewHTML(for: model.selectedIndex),
                baseURL: model.document.fileURL.deletingLastPathComponent()
            )
            .frame(width: max(canvasSize.width, 1), height: max(canvasSize.height, 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)

            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(model.selectedIndex + 1) / \(model.slideCount)")
                            .font(.caption.weight(.semibold))
                        Text("1280 × 720")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(SlideLayoutMetrics.canvasPadding)
                }
                Spacer()
            }
        }
    }

    // MARK: - Editor panel

    private var editorPanel: some View {
        VStack(spacing: 0) {
            Picker("편집", selection: $editMode) {
                ForEach(EditorPanel.allCases, id: \.self) { panel in
                    Text(panel.rawValue).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch editMode {
                case .content:
                    contentEditor
                case .html:
                    htmlEditor
                case .style:
                    styleEditor
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
    }

    private var contentEditor: some View {
        let plain = plainText(from: model.selectedSlide.innerHTML)
        return TextEditor(text: Binding(
            get: { plain },
            set: { model.updateInnerHTML(wrapAsParagraph($0)) }
        ))
        .font(.body)
        .padding(.horizontal, 4)
        .id(model.selectedSlide.id)
        .overlay(alignment: .topLeading) {
            if plain.isEmpty {
                Text("슬라이드 텍스트를 입력하세요…")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private var htmlEditor: some View {
        TextEditor(text: Binding(
            get: { model.selectedSlide.innerHTML },
            set: { model.updateInnerHTML($0) }
        ))
        .font(.system(.footnote, design: .monospaced))
        .padding(.horizontal, 4)
        .id(model.selectedSlide.id)
    }

    private var styleEditor: some View {
        Form {
            Section("슬라이드 스타일") {
                TextField("section class", text: Binding(
                    get: { model.selectedSlide.sectionClass },
                    set: { model.updateSectionClass($0) }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                stylePresetButtons
            }

            Section {
                Text("예: title, divider, (비움)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stylePresetButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(["", "title", "divider"], id: \.self) { preset in
                    Button {
                        model.updateSectionClass(preset)
                    } label: {
                        Text(preset.isEmpty ? "기본" : preset)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                model.selectedSlide.sectionClass == preset
                                    ? Color.accentColor.opacity(0.2)
                                    : Color(.tertiarySystemFill),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("완료") { store.closeCurrent() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                if sizeClass == .regular {
                    EditButton()
                }
                Button("미리보기") { showPreview = true }
                Button {
                    model.save()
                } label: {
                    if model.isSaving {
                        ProgressView()
                    } else {
                        Text(model.isDirty ? "저장*" : "저장")
                            .fontWeight(model.isDirty ? .bold : .regular)
                    }
                }
                .disabled(model.isSaving)
            }
        }
    }

    private var slideToolBar: some View {
        HStack(spacing: 20) {
            Button { model.moveSelectedSlide(offset: -1) } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(model.selectedIndex == 0)

            Button { model.moveSelectedSlide(offset: 1) } label: {
                Image(systemName: "arrow.down")
            }
            .disabled(model.selectedIndex >= model.slideCount - 1)

            Divider().frame(height: 20)

            Button { model.duplicateSelectedSlide() } label: {
                Label("복제", systemImage: "plus.square.on.square")
            }

            Button(role: .destructive) { model.deleteSelectedSlide() } label: {
                Label("삭제", systemImage: "trash")
            }
            .disabled(model.slideCount <= 1)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var statusBinding: Binding<Bool> {
        Binding(
            get: { model.statusMessage != nil },
            set: { if !$0 { model.statusMessage = nil } }
        )
    }

    // MARK: - Helpers

    private func plainText(from html: String) -> String {
        html
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func wrapAsParagraph(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count <= 1 {
            return "<p>\(escapeHTML(String(text)))</p>"
        }
        return lines.map { line in
            line.isEmpty ? "<br>" : "<p>\(escapeHTML(String(line)))</p>"
        }.joined()
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

// MARK: - Thumbnails

private struct SlideThumbnailRow: View {
    let index: Int
    let slide: Slide
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(slide.previewText.isEmpty ? "빈 슬라이드" : slide.previewText)
                    .font(.caption)
                    .lineLimit(2)
                if !slide.sectionClass.isEmpty {
                    Text(slide.sectionClass)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}

private struct SlideThumbnailCard: View {
    let index: Int
    let slide: Slide
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemBackground))
                Text(slide.previewText.isEmpty ? " " : slide.previewText)
                    .font(.system(size: 7))
                    .lineLimit(4)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
            .frame(width: SlideLayoutMetrics.thumbnailWidth, height: SlideLayoutMetrics.thumbnailHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color(.separator), lineWidth: isSelected ? 2.5 : 1)
            )
            if !slide.sectionClass.isEmpty {
                Text(slide.sectionClass)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: SlideLayoutMetrics.thumbnailWidth, alignment: .leading)
            }
        }
    }
}
