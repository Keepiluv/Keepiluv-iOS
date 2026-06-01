//
//  TXCommentCircle.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 1/22/26.
//

import SwiftUI

/// 코멘트 입력을 위한 원형 텍스트 필드 컴포넌트입니다.
public struct TXCommentCircle: View {
    @Binding private var commentText: String
    @FocusState private var isFocused: Bool
    private let isEditable: Bool
    private let externalFocus: Binding<Bool>?
    public var onFocused: ((Bool) -> Void)?
    
    /// 코멘트 텍스트 바인딩과 편집 가능 여부를 전달해 컴포넌트를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// TXCommentCircle(
    ///     commentText: $commentText,
    ///     isEditable: true
    /// )
    /// ```
    public init(
        commentText: Binding<String>,
        isEditable: Bool,
        isFocused: Binding<Bool>? = nil,
        onFocused: ((Bool) -> Void)? = nil
    ) {
        self._commentText = commentText
        self.isEditable = isEditable
        self.externalFocus = isFocused
        self.onFocused = onFocused
    }
    
    public var body: some View {
        ZStack {
            borderCircles
            fillCircles
            textCircles
        }
        .onTapGesture {
            if isEditable {
                isFocused = isEditable
            }
        }
        .onChange(of: commentText) {
            if commentText.count > Constants.maxCount {
                commentText = String(commentText.prefix(Constants.maxCount))
            }
        }
        .onChange(of: isFocused) {
            onFocused?(isFocused)
            externalFocus?.wrappedValue = isFocused
        }
        .onChange(of: externalFocus?.wrappedValue) { _, newValue in
            guard let newValue, newValue != isFocused else { return }
            isFocused = newValue
        }
    }
}

// MARK: - SubViews
private extension TXCommentCircle {
    var borderCircles: some View {
        mergedCircleBorderShape(lineWidth: Constants.borderLineWidth)
            .fill(Color.black)
            .frame(width: Constants.totalWidth, height: Constants.circleSize)
    }
    
    var fillCircles: some View {
        mergedCircleShape(inset: Constants.borderLineWidth)
            .fill(Color.white)
            .frame(width: Constants.totalWidth, height: Constants.circleSize)
    }
    
    var textCircles: some View {
        HStack(spacing: Constants.circleSpacing) {
            ForEach(0..<Constants.maxCount, id: \.self) { index in
                Text(circleText(at: index))
                    .typography(.h1_28b)
                    .foregroundColor(
                        commentText.isEmpty ? Color.Gray.gray200 : Color.Gray.gray500
                    )
                    .overlay {
                        if isFocused && index == commentText.count {
                            cursor
                        }
                    }
                .frame(width: Constants.circleSize, height: Constants.circleSize)
            }
        }
        .background {
            TextField("", text: $commentText)
                .focused($isFocused)
                .submitLabel(.done)
                .opacity(0)
        }
    }
    
    func circleText(at index: Int) -> String {
        let textArray = Array(commentText)
        if textArray.isEmpty {
            return isFocused ? "" : String(Constants.placeholder[index])
        }

        return index < textArray.count ? String(textArray[index]) : ""
    }
    
    var cursor: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let isVisible = Int(context.date.timeIntervalSinceReferenceDate * 2).isMultiple(of: 2)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.Gray.gray500)
                .frame(width: 2, height: 28)
                .opacity(isVisible ? 1 : 0)
        }
        .allowsHitTesting(false)
    }

    func mergedCircleBorderShape(lineWidth: CGFloat) -> AnyShape {
        let outer = mergedCircleShape(inset: 0)
        let inner = mergedCircleShape(inset: lineWidth)
        return AnyShape(outer.subtracting(inner))
    }

    func mergedCircleShape(inset: CGFloat) -> AnyShape {
        let diameter = Constants.circleSize - (inset * 2)
        let step = Constants.circleSize + Constants.circleSpacing
        let baseCircle = AnyShape(
            PositionedCircleShape(
                posX: inset,
                posY: inset,
                diameter: diameter
            )
        )

        var merged = baseCircle
        for index in 1..<Constants.maxCount {
            let offsetX = CGFloat(index) * step + inset
            let nextCircle = AnyShape(
                PositionedCircleShape(
                    posX: offsetX,
                    posY: inset,
                    diameter: diameter
                )
            )
            merged = AnyShape(merged.union(nextCircle))
        }

        return merged
    }
}

private enum Constants {
    static let maxCount = 5
    static let circleSize: CGFloat = 64
    static let circleSpacing: CGFloat = -14
    static let borderLineWidth: CGFloat = 1.6
    static let totalWidth: CGFloat = (circleSize * CGFloat(maxCount))
        + (circleSpacing * CGFloat(maxCount - 1))
    static let placeholder = Array("코멘트추가")
}

private struct PositionedCircleShape: Shape {
    let posX: CGFloat
    let posY: CGFloat
    let diameter: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: CGRect(x: posX, y: posY, width: diameter, height: diameter))
    }
}

#Preview {
    @Previewable @State var text: String = ""
    TXCommentCircle(
        commentText: $text,
        isEditable: true
    )
}
