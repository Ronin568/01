import Foundation
import UIKit
import CoreMedia
import CoreVideo
import CoreGraphics

/// 将文本渲染为视频帧 (CVPixelBuffer)，用于 PiP 显示
class TextToVideoRenderer {
    private let width: Int
    private let height: Int
    private var pixelBufferPool: CVPixelBufferPool?
    
    init(width: Int = 540, height: Int = 960) {
        self.width = width
        self.height = height
        setupPixelBufferPool()
    }
    
    private func setupPixelBufferPool() {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pixelBufferPool)
    }
    
    /// 生成一帧包含文字的 CVPixelBuffer
    func createPixelBuffer(
        userName: String,
        danmakuText: String,
        aiReplyText: String,
        backgroundColor: CGColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.85).cgColor
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool!, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = createBitmapContext(pixelBuffer: buffer) else { return nil }
        
        // 绘制背景
        context.setFillColor(backgroundColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // 绘制装饰边框
        context.setStrokeColor(UIColor(red: 0.31, green: 0.69, blue: 1.0, alpha: 0.6).cgColor)
        context.setLineWidth(2)
        context.stroke(CGRect(x: 4, y: 4, width: width - 8, height: height - 8))
        
        // 绘制标题栏
        let titleRect = CGRect(x: 0, y: 0, width: width, height: 40)
        context.setFillColor(UIColor(red: 0.31, green: 0.69, blue: 1.0, alpha: 0.25).cgColor)
        context.fill(titleRect)
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor(red: 0.31, green: 0.69, blue: 1.0, alpha: 1.0)
        ]
        let title = "AI 弹幕助手"
        (title as NSString).draw(at: CGPoint(x: 16, y: 8), withAttributes: titleAttrs)
        
        // 绘制用户名
        if !userName.isEmpty {
            let userAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor(red: 0.0, green: 1.0, blue: 0.53, alpha: 1.0)
            ]
            (userName as NSString).draw(at: CGPoint(x: 16, y: 52), withAttributes: userAttrs)
        }
        
        // 绘制弹幕文本
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 19),
            .foregroundColor: UIColor.white
        ]
        let textRect = CGRect(x: 16, y: userName.isEmpty ? 52 : 80, width: width - 32, height: 100)
        (danmakuText as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: textAttrs, context: nil)
        
        // 绘制分隔线
        context.setStrokeColor(UIColor(red: 0.31, green: 0.69, blue: 1.0, alpha: 0.4).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: 16, y: 190))
        context.addLine(to: CGPoint(x: width - 16, y: 190))
        context.strokePath()
        
        // 绘制 AI 标签
        let aiLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor(red: 0.31, green: 0.69, blue: 1.0, alpha: 1.0)
        ]
        ("AI 回复:" as NSString).draw(at: CGPoint(x: 16, y: 200), withAttributes: aiLabelAttrs)
        
        // 绘制 AI 回复文本
        let replyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor.white
        ]
        let replyRect = CGRect(x: 16, y: 232, width: width - 32, height: height - 260)
        (aiReplyText as NSString).draw(with: replyRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: replyAttrs, context: nil)
        
        // 绘制底部时间戳
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let timeStr = dateFormatter.string(from: Date())
        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.gray
        ]
        (timeStr as NSString).draw(at: CGPoint(x: width - 80, y: height - 28), withAttributes: timeAttrs)
        
        UIGraphicsEndImageContext()
        return buffer
    }
    
    private func createBitmapContext(pixelBuffer: CVPixelBuffer) -> CGContext? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        
        return CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }
}
