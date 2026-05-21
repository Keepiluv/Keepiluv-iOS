//
//  View+BorderInOut.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 1/16/26.
//

import SwiftUI

extension View {
    /// 뷰의 내부에 보더를 그립니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// Text("Label")
    ///     .insideBorder(.gray, shape: RoundedRectangle(cornerRadius: 8), lineWidth: 1)
    /// ```
    @ViewBuilder
    public func insideBorder(
        _ content: some ShapeStyle,
        shape: some InsettableShape,
        lineWidth: CGFloat?
    ) -> some View {
        if let lineWidth {
            overlay(
                shape
                    .strokeBorder(content, lineWidth: lineWidth)
            )
        } else {
            self
        }
    }
    
    /// 뷰의 외부에 보더를 그립니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// Text("Label")
    ///     .outsideBorder(.gray, shape: RoundedRectangle(cornerRadius: 8), lineWidth: 1)
    /// ```
    @ViewBuilder
    public func outsideBorder(
        _ content: some ShapeStyle,
        shape: some InsettableShape,
        lineWidth: CGFloat?
    ) -> some View {
        if let lineWidth {
            background {
                shape
                    .stroke(content, lineWidth: lineWidth * 2)
            }
        } else {
            self
        }
    }
    
    /// 사각형 뷰의 특정 엣지에만 보더를 그립니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// Rectangle()
    ///     .insideRectEdgeBorder(width: 1, edges: [.top, .bottom], color: .gray)
    /// ```
    public func insideRectEdgeBorder(
        width: CGFloat,
        edges: [Edge],
        color: Color
    ) -> some View {
        overlay {
            ZStack {
                ForEach(edges, id: \.self) { edge in
                    Rectangle()
                        .fill(color)
                        .frame(
                            width: edge.isVertical ? width : nil,
                            height: edge.isHorizontal ? width : nil
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge.alignment)
                }
            }
        }
    }
}

private extension Edge {
    var alignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
    
    var isHorizontal: Bool {
        self == .top || self == .bottom
    }
    
    var isVertical: Bool {
        self == .leading || self == .trailing
    }
}
