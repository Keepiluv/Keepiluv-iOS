//
//  View+TxDataRetry.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 6/8/26.
//

import SwiftUI

public extension View {
    /// 데이터 로드 실패 상태에서 재시도 안내 View를 overlay로 표시합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// content
    ///     .txDataRetry(
    ///         isPresented: store.isFetchFailed,
    ///         onRetry: { store.send(.view(.dataRetryTapped)) }
    ///     )
    /// ```
    ///
    /// - Parameters:
    ///   - isPresented: 재시도 안내 View 표시 여부입니다.
    ///   - onRetry: 재시도 버튼을 탭했을 때 실행할 동작입니다.
    func txDataRetry(
        isPresented: Bool,
        onRetry: @escaping () -> Void
    ) -> some View {
        modifier(
            TXDataRetryModifier(
                isPresented: isPresented,
                onRetry: onRetry
            )
        )
    }
}

private struct TXDataRetryModifier: ViewModifier {
    let isPresented: Bool
    let onRetry: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    if isPresented {
                        DataRetryView(onTap: onRetry)
                            .position(
                                x: proxy.size.width / 2,
                                y: proxy.size.height / 2
                            )
                    }
                }
            }
    }
}
