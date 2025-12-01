//
//  SystemModule.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit
import MediaPlayer
import AVFoundation

/// 系统功能模块
/// 提供亮度、音量等系统级功能
public class SystemModule: PimeierModule {
    public static let moduleName = "System"
    
    public required init() {}
    
    public func methods() -> [String: PimeierModuleMethod] {
        return [
            "getBrightness": getBrightness,
            "setBrightness": setBrightness,
            "getVolume": getVolume,
            "setVolume": setVolume
        ]
    }
    
    /// 获取当前屏幕亮度
    /// 返回 0.0 - 1.0 之间的值
    private func getBrightness(params: [String: Any], callback: PimeierModuleCallback) {
        let brightness = UIScreen.main.brightness
        callback.success(brightness)
    }
    
    /// 设置屏幕亮度
    /// 参数: { "value": 0.0-1.0 }
    private func setBrightness(params: [String: Any], callback: PimeierModuleCallback) {
        guard let valueAny = params["value"] else {
            callback.failure("Missing parameter: value (0.0-1.0)")
            return
        }

        let value: Double
        switch valueAny {
        case let d as Double:
            value = d
        case let f as Float:
            value = Double(f)
        case let i as Int:
            value = Double(i)
        case let s as String:
            value = Double(s) ?? 0 // 如果你不想支持 string，可以删掉
        default:
            callback.failure("Invalid type for value")
            return
        }
        
        let brightness = max(0.0, min(1.0, Double(value)))
        UIScreen.main.brightness = CGFloat(brightness)
        
        callback.success(brightness)
    }
    
    /// 获取当前系统音量
    /// 返回 0.0 - 1.0 之间的值
    private func getVolume(params: [String: Any], callback: PimeierModuleCallback) {
        // 使用 AVAudioSession 获取音量
        let audioSession = AVAudioSession.sharedInstance()
        
        // 注意：iOS 没有直接获取系统音量的 API，这里使用 MPVolumeView 的方式
        // 或者使用 AVAudioSession 的输出音量（如果可用）
        var volume: Float = 0.5 // 默认值
        
        // 尝试从 AVAudioSession 获取
        do {
            try audioSession.setActive(true)
            volume = audioSession.outputVolume
        } catch {
            print("⚠️ [System] Failed to get volume: \(error)")
        }
        
        callback.success(volume)
    }
    
    /// 设置系统音量
    /// 参数: { "value": 0.0-1.0 }
    /// 注意：iOS 系统限制，应用无法直接设置系统音量
    /// 这里使用 MPVolumeView 的私有 API（不推荐，但可用）
    /// 或者返回提示信息，建议使用系统音量控制
    private func setVolume(params: [String: Any], callback: PimeierModuleCallback) {
        guard let valueAny = params["value"] else {
            callback.failure("Missing parameter: value (0.0-1.0)")
            return
        }

        let value: Double
        switch valueAny {
        case let d as Double:
            value = d
        case let f as Float:
            value = Double(f)
        case let i as Int:
            value = Double(i)
        case let s as String:
            value = Double(s) ?? 0 // 如果你不想支持 string，可以删掉
        default:
            callback.failure("Invalid type for value")
            return
        }
        let volume = max(0.0, min(1.0, Float(value)))
        
        // iOS 系统限制：应用无法直接设置系统音量
        // 但我们可以通过 MPVolumeView 的私有 API 来设置（不推荐，可能被拒审）
        // 或者使用 AVAudioPlayer 设置应用内音量（不影响系统音量）
        
        // 方案：使用 MPVolumeView 的私有 API（仅用于演示，生产环境需谨慎）
        // 注意：使用私有 API 可能导致 App Store 审核被拒
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.isHidden = true
        
        // 查找音量滑块
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.value = volume
            // 触发值变化事件
            slider.sendActions(for: .valueChanged)
            callback.success(volume)
        } else {
            // 如果无法设置，返回当前音量
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setActive(true)
                let currentVolume = audioSession.outputVolume
                callback.failure("iOS system restriction: Cannot directly set system volume. Current volume: \(currentVolume). Please use system volume controls.")
            } catch {
                callback.failure("Failed to get volume: \(error.localizedDescription)")
            }
        }
    }
}

