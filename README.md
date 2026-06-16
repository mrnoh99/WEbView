# HTML 뷰어 (iPad/iPhone)

iPad·iPhone 의 **Files 앱에 저장된 HTML 파일을 Safari 와 동일한 품질로 열어서
보여주는** SwiftUI 앱입니다. iOS 에서는 저장된 `.html` 파일을 Safari 로 직접 여는 것이
제한되는데, 이 앱이 그 역할을 대신합니다.

## 왜 Safari 와 같은가
화면 렌더링에 **`WKWebView`** 를 사용합니다. `WKWebView` 는 Safari 와 똑같은 WebKit
엔진을 쓰므로, HTML/CSS/JavaScript 표시 결과가 Safari 와 동일합니다.

## 주요 기능
- **파일 열기**: 시스템 문서 선택기로 저장된 HTML 파일 선택
- **폴더 열기**: 이미지·CSS·JS 가 함께 있는 페이지는 폴더째 선택 → 리소스까지 모두 표시
- **다른 앱에서 열기**: Files 앱 등에서 공유 → `HTML 뷰어`, 또는 "다음으로 열기" 지원
  (`CFBundleDocumentTypes` + `LSSupportsOpeningDocumentsInPlace`)
- **샌드박스 복사 방식**: 선택한 파일/폴더를 앱 내부(`Documents/Imported/`)로 복사해
  로드하므로 "outside the sandbox" 오류 없이 안정적으로 동작하고, 앱을 다시 켜도 재접근 가능
- **상대경로 리소스 로딩**: 복사된 폴더에 읽기 권한을 줘 CSS·JS·이미지를 함께 로드
  (`loadFileURL(_:allowingReadAccessTo:)`)
- **Safari 스타일 크롬**: 뒤로/앞으로, 새로고침/정지, 로딩 진행 표시줄, 공유
- **제스처**: 가장자리 스와이프로 뒤로/앞으로 이동

> ⚠️ **단일 HTML 파일**만 선택하면 그 파일만 복사됩니다. 사진·스타일이 별도 파일로
> 분리된 페이지(예: 포함된 `index.html` + `style.css`)는 **‘폴더 열기’** 로 폴더를
> 통째로 선택해야 모든 리소스가 표시됩니다.

## 빌드 및 실행
1. Xcode 16 이상에서 `WebView.xcodeproj` 를 엽니다.
2. 타깃 `WebView` 를 선택하고, 서명(Signing & Capabilities)에서 본인 Apple 계정 팀을 지정합니다.
   - 무료 계정도 가능하지만 `PRODUCT_BUNDLE_IDENTIFIER`(`com.example.WebView`)를
     고유한 값으로 바꿔야 할 수 있습니다.
3. 실제 iPad/iPhone 또는 시뮬레이터를 선택해 실행(⌘R)합니다.

> 요구 사항: iOS/iPadOS 16.0 이상

## 사용법
- 앱을 열고 **‘파일 열기’** → HTML 파일 선택.
- 또는 Files 앱에서 HTML 파일을 길게 눌러 **공유 / 다음으로 열기 → HTML 뷰어** 선택.
- 여러 파일·이미지로 구성된 사이트라면, HTML 과 리소스가 **같은 폴더(또는 하위 폴더)** 에
  있어야 그림과 스타일이 함께 표시됩니다.

## 프로젝트 구조
```
WebView/
├── WebViewApp.swift     앱 진입점 · onOpenURL 처리
├── ContentView.swift    최근 파일 목록 · 파일 열기 화면
├── BrowserView.swift    전체 화면 뷰어(상·하단 도구막대)
├── WebView.swift        WKWebView 래퍼 + 로딩 상태 모델 + 공유 시트
├── DocumentPicker.swift 시스템 문서 선택기
├── RecentsStore.swift   최근 파일 저장 · 보안 스코프 북마크 관리
├── Info.plist           문서 타입 등록 · 권한 설정
└── Assets.xcassets      앱 아이콘 · 강조 색상
```

## 참고
- 빈 `AppIcon` 슬롯만 포함되어 있습니다. App Store 배포나 깔끔한 아이콘이 필요하면
  `Assets.xcassets/AppIcon.appiconset` 에 1024×1024 PNG 를 추가하세요.
- 원격(http/https) 리소스를 참조하는 HTML 도 표시할 수 있도록
  `NSAppTransportSecurity` 가 허용되어 있습니다.
