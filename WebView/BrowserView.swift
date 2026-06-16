import SwiftUI

/// 선택한 HTML 문서를 Safari 스타일의 크롬(상·하단 도구막대)과 함께 보여주는 뷰어.
struct BrowserView: View {
    let document: OpenedDocument
    /// 편집 가능한 문서일 때만 전달된다. nil 이면 편집 버튼을 숨긴다.
    var onEdit: (() -> Void)? = nil

    @EnvironmentObject var store: RecentsStore
    @StateObject private var model = WebViewModel()
    @State private var showShare = false
    @State private var isFullscreen = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebView(model: model)
                    .ignoresSafeArea(edges: isFullscreen ? .all : .bottom)

                if model.isLoading, !isFullscreen {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }

                if let message = model.errorMessage {
                    errorBanner(message)
                }

                if isFullscreen {
                    fullscreenExitButton
                }
            }
            .navigationTitle(displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
            .toolbar(isFullscreen ? .hidden : .visible, for: .bottomBar)
            .toolbar { toolbarContent }
            .statusBarHidden(isFullscreen)
        }
        .onAppear {
            model.load(fileURL: document.url, readAccessURL: document.readAccessURL)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [document.url])
        }
    }

    private var displayTitle: String {
        model.pageTitle.isEmpty ? document.url.lastPathComponent : model.pageTitle
    }

    // MARK: - 도구막대

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("완료") {
                store.closeCurrent()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("편집")
                }

                Button {
                    toggleFullscreen()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel("전체화면")

                Button {
                    if model.isLoading { model.stop() } else { model.reload() }
                } label: {
                    Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
                }
            }
        }

        // 하단: reveal.js 슬라이드 또는 브라우저 기록 이동.
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                model.slidePrevious()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!model.isRevealPresentation && !model.canGoBack)

            Spacer()

            Button {
                model.slideNext()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.isRevealPresentation && !model.canGoForward)

            Spacer()

            Button {
                showShare = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }

    private var fullscreenExitButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    toggleFullscreen()
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding()
            }
            Spacer()
        }
    }

    private func toggleFullscreen() {
        isFullscreen.toggle()
        model.togglePresentationFullscreen(active: isFullscreen)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                .padding()
        }
    }
}
