//
//  TXButtonShape.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 4/3/26.
//

import SwiftUI

// swiftlint:disable identifier_name
/// `TXButton`이 렌더링할 버튼의 형태와 스타일 값을 정의하는 타입입니다.
///
/// shape별로 사용할 수 있는 style, size, state를 함께 전달해 버튼의 시각 속성을 결정합니다.
///
/// ## 사용 예시
/// ```swift
/// let shape = TXButtonShape.square(
///     style: .lineIcon(icon: Image.Icon.Symbol.closeM),
///     size: .m,
///     state: .standard,
///     edges: [.top, .bottom, .trailing]
/// )
/// ```
public enum TXButtonShape {
    case rect(
        style: TXRectStyle,
        size: TXRectSize,
        state: TXRectState
    )
    case square(
        style: TXSquareStyle,
        size: TXSquareSize,
        state: TXSquareState,
        edges: [Edge]
    )
    case round(
        style: TXRoundStyle,
        size: TXRoundSize,
        state: TXRoundState
    )
    case circle(
        style: TXCircleStyle,
        size: TXCircleSize,
        state: TXCircleState
    )
    
    // MARK: - Rect
    /// 사각형 버튼의 표시 방식을 정의하는 타입입니다.
    public enum TXRectStyle {
        case basic(text: String, typography: TypographyToken? = nil)
        case round(text: String)
    }
    
    /// 사각형 버튼의 크기 단계를 정의하는 타입입니다.
    public enum TXRectSize {
        case l
        case m
        case s
    }

    /// 사각형 버튼의 상태와 색상 값을 정의하는 타입입니다.
    public enum TXRectState {
        case standard
        case line
        case disabled
        case custom(
            foregroundColor: Color,
            backgroundColor: Color,
            borderColor: Color,
            borderWidth: CGFloat?
        )
    }
    
    // MARK: - Square
    /// 모서리 일부를 둥글게 처리하는 사각 버튼의 표시 방식을 정의하는 타입입니다.
    public enum TXSquareStyle {
        case lineIcon(icon: Image)
        case lineText(text: String)
    }
    
    /// 모서리 일부를 둥글게 처리하는 사각 버튼의 크기 단계를 정의하는 타입입니다.
    public enum TXSquareSize {
        case m
    }
    
    /// 모서리 일부를 둥글게 처리하는 사각 버튼의 상태를 정의하는 타입입니다.
    public enum TXSquareState {
        case standard
    }
    
    // MARK: - Round
    /// 캡슐 형태의 라운드 버튼 표시 방식을 정의하는 타입입니다.
    public enum TXRoundStyle {
        case illustLight(text: String)
        case lillustDark(text: String)
    }
    
    /// 캡슐 형태의 라운드 버튼 크기 단계를 정의하는 타입입니다.
    public enum TXRoundSize {
        case l
        case m
        case s
    }
    
    /// 캡슐 형태의 라운드 버튼 상태를 정의하는 타입입니다.
    public enum TXRoundState {
        case standard
        case disabled
    }
    
    // MARK: - Circle
    /// 원형 아이콘 버튼의 표시 방식을 정의하는 타입입니다.
    public enum TXCircleStyle {
        case basic(icon: Image)
        case glass(icon: Image)
    }
    
    /// 원형 아이콘 버튼의 크기 값을 정의하는 타입입니다.
    public enum TXCircleSize {
        case m
        case s
        case custom(frameSize: CGSize, iconSize: CGSize)
    }
    
    /// 원형 아이콘 버튼의 상태와 색상 값을 정의하는 타입입니다.
    public enum TXCircleState {
        case standard
        case disabled
        case line
        case custom(
            foregroundColor: Color,
            backgroundColor: Color,
            borderColor: Color = .clear,
            borderWidth: CGFloat? = nil,
            isDisabled: Bool = false
        )
    }
}
// swiftlint:enable identifier_name
