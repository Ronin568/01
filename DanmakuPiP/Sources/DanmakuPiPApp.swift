import SwiftUI

@main
struct DanmakuPiPApp: App {
    @StateObject private var webSocketManager = WebSocketManager()
    @StateObject private var pipManager = PiPManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(webSocketManager)
                .environmentObject(pipManager)
                .onReceive(webSocketManager.$latestPair) { pair in
                    guard let pair = pair else { return }
                    let item = DisplayItem(
                        user: pair.selected.user,
                        danmakuText: pair.selected.text,
                        aiReplyText: pair.reply.text,
                        timestamp: Date()
                    )
                    pipManager.updateContent(with: item)
                }
        }
    }
}
