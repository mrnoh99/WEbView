import SwiftUI

/// 편집 중인 슬라이드 덱을 발표 모드로 미리본다.
struct SlideDeckPreviewView: View {
    @ObservedObject var editorModel: SlideEditorViewModel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var webModel = WebViewModel()
    @State private var isFullscreen = false

    private var document: RevealSlideDocument { editorModel.document }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebView(model: webModel)
                    .ignoresSafeArea(edges: isFullscreen ? .all : .bottom)

                if webModel.isLoading, !isFullscreen {
                    ProgressView(value: webModel.progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }

                if let message = webModel.errorMessage {
                    errorBanner(message)
                }

                if isFullscreen {
                    fullscreenExitButton
                }
            }
            .navigationTitle(document.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
            .toolbar(isFullscreen ? .hidden : .visible, for: .bottomBar)
            .toolbar { toolbarContent }
            .statusBarHidden(isFullscreen)
        }
        .onAppear { loadPresentation() }
    }

    private func loadPresentation() {
        do {
            try document.write()
            editorModel.isDirty = false
        } catch {
            webModel.errorMessage = "저장 실패: \(error.localizedDescription)"
            return
        }

        let file = document.fileURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: file.path) else {
            webModel.errorMessage = "HTML 파일을 찾을 수 없습니다."
            return
        }

        let bundleFolder = file.deletingLastPathComponent()
        let vendorJS = bundleFolder.appendingPathComponent("vendor/reveal.js/reveal.min.js")
        guard FileManager.default.fileExists(atPath: vendorJS.path) else {
            webModel.errorMessage =
                "vendor/reveal.js 가 없습니다. ‘열기 → 폴더 열기’로 AuSom-PU 폴더 전체를 다시 선택하세요."
            return
        }

        webModel.load(fileURL: file, readAccessURL: bundleFolder)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("닫기") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    toggleFullscreen()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel("전체화면")

                Button {
                    if webModel.isLoading { webModel.stop() } else { loadPresentation() }
                } label: {
                    Image(systemName: webModel.isLoading ? "xmark" : "arrow.clockwise")
                }
            }
        }

        ToolbarItemGroup(placement: .bottomBar) {
            Button { webModel.slidePrevious() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!webModel.isRevealPresentation && !webModel.canGoBack)

            Spacer()

            Button { webModel.slideNext() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!webModel.isRevealPresentation && !webModel.canGoForward)

            Spacer()

            Color.clear.frame(width: 28, height: 28)
        }
    }

    private var fullscreenExitButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { toggleFullscreen() } label: {
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
        webModel.togglePresentationFullscreen(active: isFullscreen)
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
