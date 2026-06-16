import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RecentsStore
    @State private var showingPicker = false

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
                    Button {
                        showingPicker = true
                    } label: {
                        Label("파일 열기", systemImage: "folder.badge.plus")
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
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { url in
                store.open(externalURL: url)
            }
            .ignoresSafeArea()
        }
        // 파일을 열면 전체 화면 뷰어 표시. 다른 앱에서 열기로 들어와도 동일.
        .fullScreenCover(item: $store.current) { document in
            BrowserView(document: document)
                .environmentObject(store)
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
            Text("‘파일 열기’를 눌러 Files 앱에 저장된\nHTML 파일을 선택하세요.\n다른 앱의 공유 메뉴에서 ‘HTML 뷰어’를 선택해도 됩니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingPicker = true
            } label: {
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

#Preview {
    ContentView()
        .environmentObject(RecentsStore())
}
