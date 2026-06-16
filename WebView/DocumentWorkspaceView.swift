import SwiftUI

/// 열린 문서의 작업 공간. **뷰어가 기본**이며, 편집 가능한 문서(reveal.js 슬라이드)일 때
/// 뷰어의 ‘편집’ 버튼으로 에디터에 진입한다.
struct DocumentWorkspaceView: View {
    let document: OpenedDocument

    @EnvironmentObject var store: RecentsStore
    @State private var mode: Mode = .viewer
    @State private var editTarget: EditTarget = .none

    private enum Mode {
        case viewer
        case editor(RevealSlideDocument)
        case deckPicker([URL])
    }

    /// 현재 문서에서 편집 가능한 대상.
    private enum EditTarget {
        case none                       // 편집 불가 (일반 HTML)
        case deck(RevealSlideDocument)  // 현재 문서 자체가 편집 가능한 덱
        case candidates([URL])          // 같은 폴더의 편집 가능한 덱들
    }

    var body: some View {
        Group {
            switch mode {
            case .viewer:
                BrowserView(document: document, onEdit: editAction)
            case .editor(let doc):
                SlideEditorView(document: doc, onClose: { mode = .viewer })
            case .deckPicker(let urls):
                deckPickerView(urls)
            }
        }
        .task { resolveEditability() }
    }

    /// 뷰어에 넘길 ‘편집’ 동작. 편집 대상이 없으면 nil → 버튼이 숨겨진다.
    private var editAction: (() -> Void)? {
        switch editTarget {
        case .none:
            return nil
        case .deck(let doc):
            return { mode = .editor(doc) }
        case .candidates(let urls):
            return {
                if urls.count == 1, let only = urls.first {
                    openDeck(only)
                } else {
                    mode = .deckPicker(urls)
                }
            }
        }
    }

    private func deckPickerView(_ urls: [URL]) -> some View {
        NavigationStack {
            List {
                Section {
                    Text("편집할 슬라이드 HTML 을 선택하세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("슬라이드 덱") {
                    ForEach(urls, id: \.path) { url in
                        Button {
                            openDeck(url)
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.stack")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading) {
                                    Text(url.lastPathComponent)
                                        .foregroundStyle(.primary)
                                    if let count = slideCount(at: url) {
                                        Text("\(count)장")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("편집할 슬라이드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        mode = .viewer
                    } label: {
                        Label("뷰어", systemImage: "chevron.left")
                    }
                }
            }
        }
    }

    // MARK: - 판별 / 진입

    /// 현재 문서가 편집 가능한지 조사해 editTarget 을 설정한다. (뷰어 표시는 그대로 유지)
    private func resolveEditability() {
        if let reveal = try? RevealSlideDocument.load(
            from: document.url,
            readAccessURL: document.readAccessURL
        ) {
            editTarget = .deck(reveal)
            return
        }

        let folder = document.url.deletingLastPathComponent()
        let decks = RevealSlideDocument.revealDeckURLs(in: folder)
        if !decks.isEmpty {
            editTarget = .candidates(decks)
        }
    }

    private func openDeck(_ url: URL) {
        do {
            let doc = try RevealSlideDocument.load(from: url, readAccessURL: document.readAccessURL)
            mode = .editor(doc)
        } catch {
            store.errorMessage = error.localizedDescription
            mode = .viewer
        }
    }

    private func slideCount(at url: URL) -> Int? {
        guard let doc = try? RevealSlideDocument.load(from: url, readAccessURL: document.readAccessURL) else {
            return nil
        }
        return doc.slides.count
    }
}
