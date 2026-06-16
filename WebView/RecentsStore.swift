import Foundation

/// 최근 연 항목. 선택한 파일/폴더는 앱 샌드박스(`Documents/Imported/<importID>/`)로
/// 복사되므로, 보안 스코프 없이도 언제든 다시 열 수 있다.
struct RecentItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    /// `Documents/Imported/` 아래의 고유 폴더 이름.
    var importID: String
    /// import 폴더 기준 진입 HTML 의 상대 경로.
    var entryRelativePath: String
    var lastOpened: Date

    init(id: UUID = UUID(), name: String, importID: String, entryRelativePath: String, lastOpened: Date = Date()) {
        self.id = id
        self.name = name
        self.importID = importID
        self.entryRelativePath = entryRelativePath
        self.lastOpened = lastOpened
    }
}

/// 현재 화면에 표시할 문서.
struct OpenedDocument: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    static func == (lhs: OpenedDocument, rhs: OpenedDocument) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class RecentsStore: ObservableObject {
    @Published private(set) var recents: [RecentItem] = []
    @Published var current: OpenedDocument?
    @Published var errorMessage: String?

    private let key = "recents.v2"
    private let maxRecents = 50

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var importedRoot: URL {
        documentsURL.appendingPathComponent("Imported", isDirectory: true)
    }

    init() {
        load()
    }

    // MARK: - 열기

    /// 문서/폴더 선택기 또는 "다음으로 열기"로 들어온 외부 항목을 샌드박스로 복사 후 연다.
    func open(externalURL url: URL) {
        do {
            let result = try importCopy(of: url)
            let item = RecentItem(
                name: result.displayName,
                importID: result.importID,
                entryRelativePath: result.entryRelativePath
            )
            upsert(item)
            current = OpenedDocument(url: result.entryURL)
        } catch {
            errorMessage = "파일을 열 수 없습니다: \(error.localizedDescription)"
        }
    }

    /// 최근 목록에서 다시 연다.
    func open(recent item: RecentItem) {
        let entry = importedRoot
            .appendingPathComponent(item.importID, isDirectory: true)
            .appendingPathComponent(item.entryRelativePath)

        guard FileManager.default.fileExists(atPath: entry.path) else {
            // 사본이 사라졌으면 목록에서 제거.
            remove(item)
            errorMessage = "파일을 찾을 수 없어 목록에서 제거했습니다."
            return
        }

        var updated = item
        updated.lastOpened = Date()
        upsert(updated)
        current = OpenedDocument(url: entry)
    }

    func closeCurrent() {
        current = nil
    }

    // MARK: - 가져오기(복사)

    private struct ImportResult {
        let importID: String
        let entryRelativePath: String
        let entryURL: URL
        let displayName: String
    }

    private func importCopy(of source: URL) throws -> ImportResult {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        try fm.createDirectory(at: importedRoot, withIntermediateDirectories: true)

        let importID = UUID().uuidString
        let importFolder = importedRoot.appendingPathComponent(importID, isDirectory: true)
        try fm.createDirectory(at: importFolder, withIntermediateDirectories: true)

        var isDir: ObjCBool = false
        fm.fileExists(atPath: source.path, isDirectory: &isDir)

        let destination = importFolder.appendingPathComponent(source.lastPathComponent)
        try coordinatedCopy(from: source, to: destination)

        let entryURL: URL
        let displayName: String
        if isDir.boolValue {
            // 폴더 안에서 진입 HTML 을 찾는다.
            guard let found = findEntryHTML(in: destination) else {
                try? fm.removeItem(at: importFolder)
                throw ViewerError.noHTMLInFolder
            }
            entryURL = found
            displayName = source.lastPathComponent
        } else {
            entryURL = destination
            displayName = source.lastPathComponent
        }

        let entryRelativePath = relativePath(of: entryURL, base: importFolder)
        return ImportResult(
            importID: importID,
            entryRelativePath: entryRelativePath,
            entryURL: entryURL,
            displayName: displayName
        )
    }

    /// iCloud 등 아직 내려받지 않은 파일도 처리할 수 있도록 파일 코디네이터로 복사.
    private func coordinatedCopy(from source: URL, to destination: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var copyError: Error?

        coordinator.coordinate(readingItemAt: source, options: [.withoutChanges], error: &coordinatorError) { url in
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: url, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinatorError { throw error }
        if let error = copyError { throw error }
    }

    private func findEntryHTML(in folder: URL) -> URL? {
        let fm = FileManager.default
        let htmlExtensions = ["html", "htm", "xhtml"]

        // 최상위 index.html 우선.
        let index = folder.appendingPathComponent("index.html")
        if fm.fileExists(atPath: index.path) { return index }

        guard let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: nil) else { return nil }
        var firstHTML: URL?
        for case let url as URL in enumerator {
            if htmlExtensions.contains(url.pathExtension.lowercased()) {
                if url.lastPathComponent.lowercased() == "index.html" { return url }
                if firstHTML == nil { firstHTML = url }
            }
        }
        return firstHTML
    }

    private func relativePath(of url: URL, base: URL) -> String {
        let basePath = base.standardizedFileURL.path
        let fullPath = url.standardizedFileURL.path
        if fullPath.hasPrefix(basePath) {
            return String(fullPath.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return url.lastPathComponent
    }

    // MARK: - 최근 목록 관리

    func remove(_ item: RecentItem) {
        deleteImportFolder(for: item)
        recents.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        for item in recents { deleteImportFolder(for: item) }
        recents.removeAll()
        save()
    }

    private func deleteImportFolder(for item: RecentItem) {
        let folder = importedRoot.appendingPathComponent(item.importID, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
    }

    private func upsert(_ item: RecentItem) {
        // 같은 이름의 기존 항목이 있으면 사본을 정리하고 교체.
        for existing in recents where existing.name == item.name && existing.id != item.id {
            deleteImportFolder(for: existing)
        }
        recents.removeAll { $0.name == item.name && $0.id != item.id }
        recents.removeAll { $0.id == item.id }
        recents.insert(item, at: 0)
        recents.sort { $0.lastOpened > $1.lastOpened }
        if recents.count > maxRecents {
            let overflow = recents[maxRecents...]
            overflow.forEach { deleteImportFolder(for: $0) }
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

enum ViewerError: LocalizedError {
    case noHTMLInFolder

    var errorDescription: String? {
        switch self {
        case .noHTMLInFolder:
            return "선택한 폴더에서 HTML 파일을 찾지 못했습니다."
        }
    }
}
