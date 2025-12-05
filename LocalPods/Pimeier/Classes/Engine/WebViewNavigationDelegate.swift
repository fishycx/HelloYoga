//
//  WebViewNavigationDelegate.swift
//  Pimeier
//
//  Created by AI Assistant
//

import UIKit
import WebKit

/// WebView 导航代理
/// 处理页面加载、错误、完成等事件
class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    
    /// 加载开始回调
    var onLoadStart: ((WKWebView) -> Void)?
    
    /// 加载完成回调
    var onLoadFinish: ((WKWebView, Error?) -> Void)?
    
    /// 加载失败回调
    var onLoadError: ((WKWebView, Error) -> Void)?
    
    // MARK: - WKNavigationDelegate
    
    /// 页面开始加载
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🌐 [WebView] 开始加载页面")
        onLoadStart?(webView)
    }
    
    /// 页面加载完成
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ [WebView] 页面加载完成")
        onLoadFinish?(webView, nil)
    }
    
    /// 页面加载失败
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ [WebView] 页面加载失败: \(error.localizedDescription)")
        onLoadError?(webView, error)
        onLoadFinish?(webView, error)
    }
    
    /// 页面加载失败（临时导航）
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ [WebView] 页面加载失败（临时导航）: \(error.localizedDescription)")
        
        // 检查错误类型
        let nsError = error as NSError
        let errorCode = nsError.code
        let errorDomain = nsError.domain
        
        var errorMessage = "页面加载失败"
        
        // 根据错误码提供更友好的错误信息
        if errorDomain == NSURLErrorDomain {
            switch errorCode {
            case NSURLErrorNotConnectedToInternet:
                errorMessage = "网络连接失败，请检查网络设置"
            case NSURLErrorTimedOut:
                errorMessage = "请求超时，请稍后重试"
            case NSURLErrorCannotFindHost:
                errorMessage = "无法找到服务器，请检查 URL"
            case NSURLErrorCannotConnectToHost:
                errorMessage = "无法连接到服务器"
            case NSURLErrorNetworkConnectionLost:
                errorMessage = "网络连接中断"
            case NSURLErrorDNSLookupFailed:
                errorMessage = "DNS 查询失败"
            case NSURLErrorHTTPTooManyRedirects:
                errorMessage = "重定向次数过多"
            case NSURLErrorResourceUnavailable:
                errorMessage = "资源不可用"
            case NSURLErrorBadServerResponse:
                errorMessage = "服务器响应错误"
            case NSURLErrorCancelled:
                errorMessage = "请求已取消"
            default:
                errorMessage = "网络错误: \(error.localizedDescription)"
            }
        } else if errorDomain == "WebKitErrorDomain" {
            switch errorCode {
            case 102:
                errorMessage = "无法加载此页面（框架加载中断）"
            case 103:
                errorMessage = "无法加载此页面（框架加载超时）"
            default:
                errorMessage = "WebKit 错误: \(error.localizedDescription)"
            }
        }
        
        print("📋 [WebView] 错误详情: \(errorMessage)")
        onLoadError?(webView, error)
        onLoadFinish?(webView, error)
    }
    
    /// 决定是否允许导航
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 默认允许所有导航
        decisionHandler(.allow)
    }
    
    /// 决定是否允许响应导航
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // 默认允许所有响应
        decisionHandler(.allow)
    }
}

