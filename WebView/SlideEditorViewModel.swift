import Foundation
import SwiftUI

@MainActor
final class SlideEditorViewModel: ObservableObject {
    @Published var document: RevealSlideDocument
    @Published var selectedIndex = 0
    @Published var isDirty = false
    @Published var isSaving = false
    @Published var statusMessage: String?

    init(document: RevealSlideDocument) {
        self.document = document
    }

    var selectedSlide: Slide {
        get { document.slides[selectedIndex] }
        set {
            document.slides[selectedIndex] = newValue
            isDirty = true
        }
    }

    var slideCount: Int { document.slides.count }

    func selectSlide(at index: Int) {
        guard document.slides.indices.contains(index) else { return }
        selectedIndex = index
    }

    func updateSectionClass(_ value: String) {
        var slide = selectedSlide
        slide.sectionClass = value.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedSlide = slide
    }

    func updateInnerHTML(_ value: String) {
        var slide = selectedSlide
        slide.innerHTML = value
        selectedSlide = slide
    }

    func addSlide(after index: Int? = nil) {
        let insertAt = (index ?? selectedIndex) + 1
        let newSlide = Slide(
            sectionClass: "",
            innerHTML: #"<h2>새 슬라이드</h2><p class="sub">내용을 입력하세요.</p>"#
        )
        document.slides.insert(newSlide, at: min(insertAt, document.slides.count))
        selectedIndex = min(insertAt, document.slides.count - 1)
        isDirty = true
    }

    func deleteSelectedSlide() {
        guard document.slides.count > 1 else { return }
        document.slides.remove(at: selectedIndex)
        selectedIndex = min(selectedIndex, document.slides.count - 1)
        isDirty = true
    }

    func duplicateSelectedSlide() {
        let copy = document.slides[selectedIndex]
        document.slides.insert(copy, at: selectedIndex + 1)
        selectedIndex += 1
        isDirty = true
    }

    func moveSlide(from source: IndexSet, to destination: Int) {
        document.slides.move(fromOffsets: source, toOffset: destination)
        isDirty = true
    }

    func moveSelectedSlide(offset: Int) {
        let target = selectedIndex + offset
        guard document.slides.indices.contains(target) else { return }
        document.slides.swapAt(selectedIndex, target)
        selectedIndex = target
        isDirty = true
    }

    func save() {
        isSaving = true
        defer { isSaving = false }

        do {
            try document.write()
            isDirty = false
            statusMessage = "저장됨"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func openedDocumentForPreview() -> OpenedDocument {
        OpenedDocument(
            url: document.fileURL,
            readAccessURL: document.readAccessURL
        )
    }
}
