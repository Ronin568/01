import UIKit
import AVKit
import AVFoundation
import CoreMedia

class PiPManager: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    @Published var isPiPActive = false
    @Published var isPiPSupported = false
    
    private var displayLayer: AVSampleBufferDisplayLayer?
    private var pipController: AVPictureInPictureController?
    private var renderer: TextToVideoRenderer
    private var displayLink: CADisplayLink?
    private var currentDisplayItem: DisplayItem?
    private var frameCount: Int = 0
    
    override init() {
        self.renderer = TextToVideoRenderer(width: 540, height: 960)
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("[PiP] 音频会话设置失败: \(error.localizedDescription)")
        }
    }
    
    /// 设置 PiP 的显示层 (需在主线程调用)
    func setupPiP(with view: UIView) {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspectFill
        layer.frame = CGRect(x: 0, y: 0, width: 540, height: 960)
        // 添加到视图层级（隐藏，仅用于 PiP）
        view.layer.addSublayer(layer)
        layer.isHidden = true
        self.displayLayer = layer
        
        // 检查 PiP 支持
        isPiPSupported = AVPictureInPictureController.isPictureInPictureSupported()
        guard isPiPSupported else {
            print("[PiP] 当前设备不支持画中画")
            return
        }
        
        // 创建 PiP 控制器
        let contentSource = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
    }
    
    /// 开始 PiP 并持续渲染文字
    func startPiP() {
        guard let controller = pipController, isPiPSupported else { return }
        
        // 先渲染一帧初始画面
        if let pixelBuffer = renderer.createPixelBuffer(userName: "等待中", danmakuText: "AI 弹幕助手已连接", aiReplyText: "等待弹幕精选...") {
            enqueuePixelBuffer(pixelBuffer)
        }
        
        // 启动显示链接，持续发送帧
        startRendering()
        
        controller.startPictureInPicture()
    }
    
    /// 更新显示内容
    func updateContent(with item: DisplayItem) {
        currentDisplayItem = item
    }
    
    /// 停止 PiP
    func stopPiP() {
        stopRendering()
        pipController?.stopPictureInPicture()
        isPiPActive = false
    }
    
    // MARK: - 渲染循环
    
    private func startRendering() {
        displayLink = CADisplayLink(target: self, selector: #selector(renderFrame))
        displayLink?.preferredFramesPerSecond = 10 // 10fps 足够文字显示
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopRendering() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func renderFrame() {
        guard let displayLayer = displayLayer else { return }
        
        if displayLayer.status == .failed {
            // 重置显示层
            displayLayer.flush()
        }
        
        let item = currentDisplayItem
        let pixelBuffer: CVPixelBuffer?
        
        if let item = item {
            // 交替渲染两种样式（带闪烁效果的反色）
            if frameCount % 30 < 15 {
                pixelBuffer = renderer.createPixelBuffer(
                    userName: item.user,
                    danmakuText: item.danmakuText,
                    aiReplyText: item.aiReplyText
                )
            } else {
                // 稍暗的背景变体
                pixelBuffer = renderer.createPixelBuffer(
                    userName: item.user,
                    danmakuText: item.danmakuText,
                    aiReplyText: item.aiReplyText,
                    backgroundColor: UIColor(red: 0, green: 0, blue: 0.05, alpha: 0.9).cgColor
                )
            }
        } else {
            pixelBuffer = renderer.createPixelBuffer(
                userName: "",
                danmakuText: "等待弹幕精选...",
                aiReplyText: ""
            )
        }
        
        if let buffer = pixelBuffer {
            enqueuePixelBuffer(buffer)
        }
        
        frameCount += 1
    }
    
    private func enqueuePixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        guard let displayLayer = displayLayer else { return }
        
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 10),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        
        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        guard let formatDesc = formatDescription else { return }
        
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil,
            imageBuffer: pixelBuffer,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        if let buffer = sampleBuffer {
            displayLayer.enqueue(buffer)
            if displayLayer.status == .failed {
                displayLayer.flush()
            }
        }
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = true
        }
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = false
        }
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("[PiP] 启动失败: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isPiPActive = false
        }
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension PiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        if playing {
            startRendering()
        } else {
            stopRendering()
        }
    }
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        displayLink == nil
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        // 可根据需要调整渲染尺寸
    }
    
    func pictureInPictureControllerShouldProhibitBackgroundAudioBlending(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        true
    }
}
