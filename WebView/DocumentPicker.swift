import SwiftUI
import UniformTypeIdentifiers

/// 시스템 문서/폴더 선택기.
/// `asCopy: false` 로 원본에 접근해 보안 스코프 URL 을 받은 뒤, 호출측에서 샌드박스로 복사한다.
struct DocumentPicker: UIViewControllerRepresentable {
    enum Mode {
        case file
        case folder
    }

    var mode: Mode = .file
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        switch mode {
        case .file:
            var types: [UTType] = [.html]
            if let htm = UTType(filenameExtension: "htm") { types.append(htm) }
            if let xhtml = UTType(filenameExtension: "xhtml") { types.append(xhtml) }
            picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        case .folder:
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        }
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
