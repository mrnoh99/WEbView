import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RecentsStore
    @State private var pickerMode: DocumentPicker.Mode?
    @State private var showClearConfirm = false

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
                if !store.recents.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("목록비우기", role: .destructive) {
                            showClearConfirm = true
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    openMenu {
                        Text("열기")
                    }
                }
            }
            .confirmationDialog(
                "목록을 모두 비우시겠습니까?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("목록비우기", role: .destructive) {
                    store.clearAll()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("가져온 파일 사본도 함께 삭제됩니다.")
            }
        }
        .sheet(item: $pickerMode) { mode in
            DocumentPicker(mode: mode) { url in
                store.open(externalURL: url)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $store.current) { document in
            DocumentWorkspaceView(document: document)
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
    private func openMenu<MenuLabel: View>(@ViewBuilder label: () -> MenuLabel) -> some View {
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
            Text("‘열기’로 Files 앱의 HTML 파일이나 폴더를 선택하면\nSafari 와 동일하게 표시됩니다.\nreveal.js 슬라이드라면 ‘편집’ 버튼으로 PowerPoint처럼\n편집할 수도 있습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            openMenu {
                Label("열기", systemImage: "folder.badge.plus")
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
                if !item.subtitle.isEmpty {
                    Label(item.subtitle, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(item.lastOpened, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
