import Foundation
import Network

class WebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var latestPair: AiPairMessage?
    @Published var displayHistory: [DisplayItem] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var serverURL: URL?
    private let maxHistoryItems = 50
    
    func connect(ip: String, port: Int = 8765) {
        guard let url = URL(string: "ws://\(ip):\(port)") else {
            connectionState = .error("无效 URL")
            return
        }
        serverURL = url
        connectionState = .connecting
        
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        sendHello()
        startPing()
        receiveMessage()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session = nil
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.connectionState = .connected
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
        scheduleReconnect()
    }
    
    // MARK: - 消息接收
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // 继续接收下一条消息
                self.receiveMessage()
                
            case .failure(let error):
                print("[WS] 接收失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.connectionState = .error(error.localizedDescription)
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = dict["type"] as? String else { return }
        
        switch type {
        case "welcome":
            if let welcome = try? JSONDecoder().decode(WelcomeMessage.self, from: data) {
                print("[WS] 已连接服务器: \(welcome.message)")
            }
            
        case "ai_pair":
            if let pair = try? JSONDecoder().decode(AiPairMessage.self, from: data) {
                DispatchQueue.main.async {
                    self.latestPair = pair
                    let item = DisplayItem(
                        user: pair.selected.user,
                        danmakuText: pair.selected.text,
                        aiReplyText: pair.reply.text,
                        timestamp: Date()
                    )
                    self.displayHistory.append(item)
                    if self.displayHistory.count > self.maxHistoryItems {
                        self.displayHistory.removeFirst()
                    }
                }
            }
            
        case "status":
            if let status = try? JSONDecoder().decode(StatusMessage.self, from: data) {
                print("[WS] 状态: \(status.status) - \(status.message)")
            }
            
        case "pong":
            break // 心跳响应，忽略
            
        default:
            break
        }
    }
    
    // MARK: - 消息发送
    
    private func sendHello() {
        let hello: [String: Any] = [
            "type": "hello",
            "device": "iPhone PiP"
        ]
        sendJson(hello)
    }
    
    func sendJson(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { error in
            if let error = error {
                print("[WS] 发送失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 心跳
    
    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.sendJson(["type": "ping"])
        }
    }
    
    // MARK: - 重连
    
    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            guard let self = self, let url = self.serverURL else { return }
            print("[WS] 尝试重连...")
            self.connect(ip: url.host ?? "", port: url.port ?? 8765)
        }
    }
}
