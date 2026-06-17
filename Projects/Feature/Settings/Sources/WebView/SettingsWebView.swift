//
//  SettingsWebView.swift
//  FeatureSettings
//
//  Created by Claude on 02/09/26.
//

import ComposableArchitecture
import FeatureSettingsInterface
import SharedDesignSystem
import SwiftUI
import WebKit

/// 설정에서 사용하는 WebView 화면입니다.
/// 외부 링크로 이동할 수 없는 제한된 WebView입니다.
struct SettingsWebView: View {
    let url: URL
    let title: String
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            WebViewRepresentable(url: url)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .navigationBarBackButtonHidden(true)
    }

    private var navigationBar: some View {
        TXNavigationBar(style: .subTitle(title: title, type: .back)) { action in
            if action == .backTapped {
                store.send(.view(.subViewBackButtonTapped))
            }
        }
    }
}

// MARK: - WebView Representable

private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.backgroundColor = .white
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(originalHost: url.host)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let originalHost: String?

        init(originalHost: String?) {
            self.originalHost = originalHost
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // 같은 호스트 내에서만 네비게이션 허용
            if url.host == originalHost || navigationAction.navigationType == .other {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}
