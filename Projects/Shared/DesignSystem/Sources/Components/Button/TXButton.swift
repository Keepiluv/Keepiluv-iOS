//
//  TXButton.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 4/3/26.
//

import SwiftUI

/// 디자인 시스템의 버튼을 shape 기반으로 렌더링하는 공통 컴포넌트입니다.
///
/// `TXButtonShape`에 정의된 shape, style, size, state 조합에 따라 내부 버튼 구현을 선택합니다.
///
/// ## 사용 예시
/// ```swift
/// TXButton(
///     shape: .rect(
///         style: .basic(text: "완료"),
///         size: .l,
///         state: .standard
///     ),
///     onTap: { }
/// )
/// ```
public struct TXButton: View {
    let shape: TXButtonShape
    let allowsActionWhenDisabled: Bool
    let onTap: () -> Void
    
    /// 버튼을 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// TXButton(
    ///     shape: .circle(
    ///         style: .glass(icon: Image.Icon.Symbol.flash),
    ///         size: .m,
    ///         state: .standard
    ///     ),
    ///     onTap: { }
    /// )
    /// ```
    public init(
        shape: TXButtonShape,
        allowsActionWhenDisabled: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.shape = shape
        self.allowsActionWhenDisabled = allowsActionWhenDisabled
        self.onTap = onTap
    }
    
    @ViewBuilder
    public var body: some View {
        switch shape {
        case .rect:
            TXRectButton(
                shape: shape,
                onTap: onTap
            )
            
        case .square:
            TXSquareButton(
                shape: shape,
                onTap: onTap
            )
            
        case .round:
            TXRoundButton(
                shape: shape,
                allowsActionWhenDisabled: allowsActionWhenDisabled,
                onTap: onTap
            )
            
        case .circle:
            TXCircleButton(
                shape: shape,
                onTap: onTap
            )
        }
    }
}
