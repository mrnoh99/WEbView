import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RecentsStore
    @State private var pickerMode: DocumentPicker.Mode?

    var body: some View {
        NavigationStack {
            Group {
                if store.recents.isEmpty {
                    emptyState
                } else {
                    recentsList
                }
            }
            .navigationTitle("HTML 뷰어")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    openMenu {
                        Image(systemName: "plus")
                    }
                }
                if !store.recents.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button(role: .destructive) {
                                store.clearAll()
                            } label: {
                                Label("최근 목록 비우기", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .sheet(item: $pickerMode) { mode in
            DocumentPicker(mode: mode) { url in
                store.open(externalURL: url)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $store.current) { document in
            BrowserView(document: document)
                .environmentObject(store)
        }
        .alert(
            "알림",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            ),
            presenting: store.errorMessage
        ) { _ in
            Button("확인", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    /// 파일/폴더 열기 선택 메뉴.
    private func openMenu<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Menu {
            Button {
                pickerMode = .file
            } label: {
                Label("HTML 파일 열기", systemImage: "doc")
            }
            Button {
                pickerMode = .folder
            } label: {
                Label("폴더 열기 (리소스 포함)", systemImage: "folder")
            }
        } label: {
            label()
        }
    }

    // MARK: - 최근 목록

    private var recentsList: some View {
        List {
            Section("최근 파일") {
                ForEach(store.recents) { item in
                    Button {
                        store.open(recent: item)
                    } label: {
                        RecentRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    indexSet.map { store.recents[$0] }.forEach(store.remove)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("저장된 HTML 파일 열기")
                .font(.title2.bold())
            Text("‘＋’를 눌러 Files 앱의 HTML 파일이나 폴더를 선택하세요.\n이미지·CSS·JS 가 함께 있는 페이지는 ‘폴더 열기’를 사용하면\n리소스까지 모두 표시됩니다.\n다른 앱의 공유 메뉴에서 ‘HTML 뷰어’를 선택해도 됩니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            openMenu {
                Label("파일 열기", systemImage: "folder.badge.plus")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecentRow: View {
    let item: RecentItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.lastOpened, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

extension DocumentPicker.Mode: Identifiable {
    var id: Int {
        switch self {
        case .file: return 0
        case .folder: return 1
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RecentsStore())
}
