import SwiftUI
import UniformTypeIdentifiers

/// 시스템 문서 선택기. Files 앱처럼 어디에 있는 파일이든 골라서 열 수 있다.
/// `asCopy: false` 로 원본을 직접 열어 보안 스코프 URL 을 받는다.
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var types: [UTType] = [.html]
        if let htm = UTType(filenameExtension: "htm") { types.append(htm) }
        if let xhtml = UTType(filenameExtension: "xhtml") { types.append(xhtml) }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}
