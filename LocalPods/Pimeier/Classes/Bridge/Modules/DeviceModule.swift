//
//  DeviceModule.swift
//  HelloYoga
//
//  Created by AI Assistant
//

import UIKit
import AudioToolbox

public class DeviceModule: PimeierModule {
    public static let moduleName = "Device"
    
    public required init() {}
    
    public func methods() -> [String: PimeierModuleMethod] {
        return [
            "getInfo": getInfo,
            "vibrate": vibrate
        ]
    }
    
    private func getInfo(params: [String: Any], callback: PimeierModuleCallback) {
        let info: [String: Any] = [
            "model": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "name": UIDevice.current.name
        ]
        callback.success(info)
    }
    
    private func vibrate(params: [String: Any], callback: PimeierModuleCallback) {
        // 简单的触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        callback.success(nil)
    }
}

