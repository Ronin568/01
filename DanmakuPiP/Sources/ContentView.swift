import SwiftUI
import AVKit

struct ContentView: View {
    @EnvironmentObject private var wsManager: WebSocketManager
    @EnvironmentObject private var pipManager: PiPManager
    
    @State private var serverIP: String = ""
    @State private var serverPort: String = "8765"
    @State private var showSetup = true
    
    var body: some View {
        ZStack {
            // 隐藏的 PiP 承载视图
            PiPContainerView()
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
            
            if showSetup {
                setupView
            } else {
                mainView
            }
        }
        .onAppear {
            // 从 UserDefaults 恢复上次的 IP
            serverIP = UserDefaults.standard.string(forKey: "lastServerIP") ?? ""
            serverPort = UserDefaults.standard.string(forKey: "lastServerPort") ?? "8765"
        }
    }
    
    // MARK: - 设置页面
    
    private var setupView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image(systemName: "pip.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.bottom, 16)
            
            Text("AI 弹幕助手")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 8)
            
            Text("通过画中画显示 AI 精选弹幕与回复\n确保 iPhone 和 PC 在同一局域网")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("PC 局域网 IP")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例如 192.168.1.100", text: $serverIP)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 16)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("端口")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("8765", text: $serverPort)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
            
            Button(action: connect) {
                HStack {
                    Image(systemName: "link")
                    Text("连接到服务器")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canConnect ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!canConnect)
            .padding(.horizontal, 40)
            .padding(.bottom, 16)
            
            // 连接状态
            HStack(spacing: 8) {
                switch wsManager.connectionState {
                case .disconnected:
                    Image(systemName: "circle.slash")
                        .foregroundColor(.secondary)
                    Text("未连接")
                        .foregroundColor(.secondary)
                case .connecting:
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("连接中...")
                        .foregroundColor(.orange)
                case .connected:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已连接")
                        .foregroundColor(.green)
                case .error(let msg):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("错误: \(msg)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .font(.subheadline)
            
            Spacer()
            
            Text("v1.0 | 使用 Codemagic 构建")
                .font(.caption2)
                .foregroundColor(.tertiary)
                .padding(.bottom, 8)
        }
    }
    
    private var canConnect: Bool {
        !serverIP.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - 主页面
    
    private var mainView: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("已连接")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if pipManager.isPiPActive {
                    HStack(spacing: 4) {
                        Image(systemName: "pip.fill")
                            .font(.caption)
                        Text("悬浮窗运行中")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                } else {
                    Button(action: {
                        pipManager.startPiP()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pip")
                                .font(.caption)
                            Text("启动悬浮窗")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Button("断开") {
                    wsManager.disconnect()
                    pipManager.stopPiP()
                    withAnimation { showSetup = true }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            if pipManager.isPiPActive {
                // PiP 模式下简洁界面
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "pip.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("画中画正在运行")
                        .font(.headline)
                    Text("AI 弹幕显示在悬浮窗中\n返回桌面或切换到其他应用查看")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                // 消息列表
                messageList
            }
        }
    }
    
    @ViewBuilder
    private var messageList: some View {
        if wsManager.displayHistory.isEmpty {
            ContentUnavailableView(
                "等待弹幕精选",
                systemImage: "message",
                description: Text("AI 精选弹幕和回复将在此显示")
            )
        } else {
            List {
                ForEach(wsManager.displayHistory.reversed()) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        // 用户弹幕
                        HStack(alignment: .top) {
                            Text(item.user)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Spacer()
                            Text(item.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(item.danmakuText)
                            .font(.body)
                        
                        // AI 回复
                        HStack(alignment: .top, spacing: 6) {
                            Text("AI")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                            Text(item.aiReplyText)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - 连接
    
    private func connect() {
        let ip = serverIP.trimmingCharacters(in: .whitespaces)
        let port = Int(serverPort) ?? 8765
        guard !ip.isEmpty else { return }
        
        // 保存 IP
        UserDefaults.standard.set(ip, forKey: "lastServerIP")
        UserDefaults.standard.set(port, forKey: "lastServerPort")
        
        wsManager.connect(ip: ip, port: port)
        withAnimation { showSetup = false }
    }
}

// MARK: - PiP 容器视图

struct PiPContainerView: UIViewRepresentable {
    @EnvironmentObject private var pipManager: PiPManager
    
    func makeUIView(context: Context) -> PiPHostingUIView {
        let view = PiPHostingUIView()
        view.pipManager = pipManager
        return view
    }
    
    func updateUIView(_ uiView: PiPHostingUIView, context: Context) {}
}

class PiPHostingUIView: UIView {
    weak var pipManager: PiPManager?
    
    override class var layerClass: AnyClass {
        CALayer.self
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            pipManager?.setupPiP(with: self)
        }
    }
}
