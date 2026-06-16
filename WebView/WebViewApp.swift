import SwiftUI

@main
struct WebViewApp: App {
    @StateObject private var store = RecentsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                // Files 앱이나 다른 앱에서 "공유 → WEbView" 또는 "다음으로 열기"를
                // 통해 HTML 파일을 전달하면 이 콜백으로 URL 이 들어온다.
                .onOpenURL { url in
                    store.open(externalURL: url)
                }
        }
    }
}
