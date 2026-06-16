import SwiftUI

/// 열린 문서의 편집/선택 화면.
struct DocumentWorkspaceView: View {
    let document: OpenedDocument

    @EnvironmentObject var store: RecentsStore
    @State private var mode: WorkspaceMode = .loading

    private enum WorkspaceMode {
        case loading
        case editor(RevealSlideDocument)
        case deckPicker([URL])
        case viewer
        case error(String)
    }

    var body: some View {
        Group {
            switch mode {
            case .loading:
                ProgressView("불러오는 중…")
            case .editor(let doc):
                SlideEditorView(document: doc)
            case .deckPicker(let urls):
                deckPickerView(urls)
            case .viewer:
                BrowserView(document: document)
            case .error(let message):
                errorView(message)
            }
        }
        .task { resolveWorkspace() }
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

                Section {
                    Button {
                        mode = .viewer
                    } label: {
                        Label("뷰어로 index.html 보기", systemImage: "safari")
                    }
                }
            }
            .navigationTitle(document.url.deletingLastPathComponent().lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("완료") { store.closeCurrent() }
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        NavigationStack {
            Group {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView {
                        Label("열 수 없음", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("뷰어로 열기") { mode = .viewer }
                        Button("닫기") { store.closeCurrent() }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("열 수 없음").font(.title2.bold())
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        VStack(spacing: 8) {
                            Button("뷰어로 열기") { mode = .viewer }
                            Button("닫기") { store.closeCurrent() }
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("완료") { store.closeCurrent() }
                }
            }
        }
    }

    private func resolveWorkspace() {
        do {
            let reveal = try RevealSlideDocument.load(
                from: document.url,
                readAccessURL: document.readAccessURL
            )
            mode = .editor(reveal)
            return
        } catch SlideDocumentError.notRevealFormat {
            // index.html 등 랜딩 페이지 — 아래에서 덱 목록 탐색
        } catch {
            mode = .error(error.localizedDescription)
            return
        }

        let bundleFolder = document.url.deletingLastPathComponent()
        let decks = RevealSlideDocument.revealDeckURLs(in: bundleFolder)

        if decks.isEmpty {
            mode = .viewer
        } else if decks.count == 1, let only = decks.first {
            openDeck(only)
        } else {
            mode = .deckPicker(decks)
        }
    }

    private func openDeck(_ url: URL) {
        do {
            let doc = try RevealSlideDocument.load(from: url, readAccessURL: document.readAccessURL)
            mode = .editor(doc)
        } catch {
            mode = .error(error.localizedDescription)
        }
    }

    private func slideCount(at url: URL) -> Int? {
        guard let doc = try? RevealSlideDocument.load(from: url, readAccessURL: document.readAccessURL) else {
            return nil
        }
        return doc.slides.count
    }
}
