import SwiftUI

/// 선택한 HTML 문서를 Safari 스타일의 크롬(상·하단 도구막대)과 함께 보여주는 뷰어.
struct BrowserView: View {
    let document: OpenedDocument

    @EnvironmentObject var store: RecentsStore
    @StateObject private var model = WebViewModel()
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebView(model: model)
                    .ignoresSafeArea(edges: .bottom)

                if model.isLoading {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }

                if let message = model.errorMessage {
                    errorBanner(message)
                }
            }
            .navigationTitle(displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .onAppear {
            model.load(fileURL: document.url)
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
            Button {
                if model.isLoading { model.stop() } else { model.reload() }
            } label: {
                Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
            }
        }

        // 하단: Safari 와 비슷한 뒤로/앞으로/공유.
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                model.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!model.canGoBack)

            Spacer()

            Button {
                model.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.canGoForward)

            Spacer()

            Button {
                showShare = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
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
