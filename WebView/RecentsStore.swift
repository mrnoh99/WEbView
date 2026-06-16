import Foundation

/// 최근 연 HTML 파일 한 건. 보안 스코프 북마크(`bookmark`)로 파일 위치를
/// 저장해 두면 앱을 껐다 켜도 같은 파일에 다시 접근할 수 있다.
struct RecentItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var path: String
    var bookmark: Data
    var lastOpened: Date

    init(id: UUID = UUID(), name: String, path: String, bookmark: Data, lastOpened: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.bookmark = bookmark
        self.lastOpened = lastOpened
    }
}

/// 현재 화면에 표시할 문서. `fullScreenCover(item:)` 에 쓰기 위해 Identifiable.
struct OpenedDocument: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    static func == (lhs: OpenedDocument, rhs: OpenedDocument) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class RecentsStore: ObservableObject {
    @Published private(set) var recents: [RecentItem] = []
    /// 값이 설정되면 뷰어가 전체 화면으로 열린다.
    @Published var current: OpenedDocument?

    private let key = "recents.v1"
    private let maxRecents = 50

    /// 현재 접근 중인 보안 스코프 URL. 다음 파일을 열거나 닫을 때 해제한다.
    private var activeScopedURL: URL?

    init() {
        load()
    }

    // MARK: - 열기

    /// 문서 선택기 또는 "다음으로 열기"로 들어온 외부 파일을 연다.
    func open(externalURL url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        if let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            let item = RecentItem(name: url.lastPathComponent, path: url.path, bookmark: bookmark)
            upsert(item)
        }
        present(url: url)
    }

    /// 최근 목록에서 다시 연다.
    func open(recent item: RecentItem) {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: item.bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            // 북마크가 더 이상 유효하지 않으면 목록에서 제거.
            remove(item)
            return
        }

        var updated = item
        updated.lastOpened = Date()
        // 북마크가 오래되었으면 새로 만들어 갱신.
        if isStale {
            let scoped = url.startAccessingSecurityScopedResource()
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                updated.bookmark = fresh
            }
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        upsert(updated)
        present(url: url)
    }

    private func present(url: URL) {
        stopActiveAccess()
        if url.startAccessingSecurityScopedResource() {
            activeScopedURL = url
        }
        current = OpenedDocument(url: url)
    }

    func closeCurrent() {
        stopActiveAccess()
        current = nil
    }

    private func stopActiveAccess() {
        if let url = activeScopedURL {
            url.stopAccessingSecurityScopedResource()
            activeScopedURL = nil
        }
    }

    // MARK: - 최근 목록 관리

    func remove(_ item: RecentItem) {
        recents.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        recents.removeAll()
        save()
    }

    private func upsert(_ item: RecentItem) {
        recents.removeAll { $0.path == item.path }
        recents.insert(item, at: 0)
        recents.sort { $0.lastOpened > $1.lastOpened }
        if recents.count > maxRecents {
            recents = Array(recents.prefix(maxRecents))
        }
        save()
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let items = try? JSONDecoder().decode([RecentItem].self, from: data)
        else { return }
        recents = items.sorted { $0.lastOpened > $1.lastOpened }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
