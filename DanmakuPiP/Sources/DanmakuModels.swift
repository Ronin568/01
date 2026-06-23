import Foundation

// MARK: - WebSocket 消息模型

/// 服务端推送的消息基类
struct WsMessage: Codable {
    let type: String
    let id: String?
    let timestamp: Double?
}

/// ai_pair 消息 (精选弹幕 + AI回复)
struct AiPairMessage: Codable {
    let type: String
    let id: String
    let selected: SelectedDanmaku
    let reply: AiReply
    let timestamp: Double
}

struct SelectedDanmaku: Codable {
    let user: String
    let text: String
}

struct AiReply: Codable {
    let text: String
    let timestamp: Double
}

/// Welcome 消息
struct WelcomeMessage: Codable {
    let type: String
    let version: String
    let server_time: Double
    let message: String
}

/// 状态更新
struct StatusMessage: Codable {
    let type: String
    let status: String
    let message: String
    let timestamp: Double
}

// MARK: - App 状态

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error(String)
}

struct DisplayItem: Identifiable {
    let id = UUID()
    let user: String
    let danmakuText: String
    let aiReplyText: String
    let timestamp: Date
}
