//
//  TXRectButton.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 1/15/26.
//

import SwiftUI

struct TXRectButton: View {
    let shape: TXButtonShape
    let onTap: () -> Void
    
    public var body: some View {
        if case let .rect(style, size, state) = shape {
            Button(action: onTap) {
                Text(style.text)
                    .typography(style.typography ?? size.typhography)
                    .foregroundStyle(state.fontColor)
                    .padding(.horizontal, size.horizontalPadding)
                    .frame(minWidth: size.minWidth(style: style), maxWidth: size.maxWidth(style: style))
                    .frame(height: size.height(style: style))
                    .background(state.backgroundColor)
                    .insideBorder(
                        state.borderColor,
                        shape: RoundedRectangle(cornerRadius: size.radius(style: style)),
                        lineWidth: state.borderWidth
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: size.radius(style: style)))
            .padding(.vertical, size.outVerticalPadding)
            .buttonStyle(.plain)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Constants
private extension TXButtonShape.TXRectStyle {
    var text: String {
        switch self {
        case .basic(let text, _): text
        case .round(let text): text
        }
    }
    
    var typography: TypographyToken? {
        switch self {
        case .basic(_, let typography): typography
        case .round: nil
        }
    }
}

private extension TXButtonShape.TXRectSize {
    func maxWidth(style: TXButtonShape.TXRectStyle) -> CGFloat? {
        switch (style, self) {
        case (.basic, .l): .infinity
        case (.basic, .m): 151
        case (.basic, .s): nil
        case (.round, .s): .infinity
        case (.round, .m), (.round, .l): nil
        }
    }
    
    func minWidth(style: TXButtonShape.TXRectStyle) -> CGFloat? {
        switch (style, self) {
        case (.basic, .l), (.basic, .m): nil
        case (.basic, .s): 56
        case (.round, .s): 100
        case (.round, .m), (.round, .l): nil
        }
    }
    
    func height(style: TXButtonShape.TXRectStyle) -> CGFloat? {
        switch (style, self) {
        case (.basic, .l), (.basic, .m): 52
        case (.basic, .s): 32
        case (.round, .s): 42
        case (.round, .m), (.round, .l): nil
        }
    }
    
    var typhography: TypographyToken {
        switch self {
        case .l, .m: .t2_16b
        case .s: .b1_14b
        }
    }
    
    func radius(style: TXButtonShape.TXRectStyle) -> CGFloat {
        switch (style, self) {
        case (.basic, .l), (.basic, .m): Radius.s
        case (.basic, .s): Radius.xs
        case (.round, .s): 999
        case (.round, .m), (.round, .l): .zero
        }
    }
        
    var horizontalPadding: CGFloat {
        switch self {
        case .s: Spacing.spacing6
        case .l, .m: .zero
        }
    }
    
    var outVerticalPadding: CGFloat {
        switch self {
        case .l: Spacing.spacing5
        case .m, .s: .zero
        }
    }
}

private extension TXButtonShape.TXRectState {
    var borderWidth: CGFloat? {
        switch self {
        case .line: LineWidth.m
        case .disabled, .standard: nil
        case let .custom(_, _, _, borderWidth): borderWidth
        }
    }
    
    var borderColor: Color {
        switch self {
        case .line: Color.Gray.gray500
        case .disabled: Color.Gray.gray100
        case .standard: .clear
        case let .custom(_, _, borderColor, _): borderColor
        }
    }
    
    var fontColor: Color {
        switch self {
        case .line: Color.Gray.gray500
        case .disabled: Color.Gray.gray300
        case .standard: Color.Common.white
        case let .custom(foregroundColor, _, _, _): foregroundColor
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .line: Color.Common.white
        case .disabled: Color.Gray.gray100
        case .standard: Color.Gray.gray500
        case let .custom(_, backgroundColor, _, _): backgroundColor
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.spacing7) {
        VStack(alignment: .leading, spacing: Spacing.spacing3) {
            Text("L")
                .font(.headline)
            
            TXButton(
                shape: .rect(style: .basic(text: "버튼 이름"), size: .l, state: .standard),
                onTap: { }
            )
        }
        
        VStack(alignment: .leading, spacing: Spacing.spacing3) {
            Text("M")
                .font(.headline)
            
            TXButton(
                shape: .rect(style: .basic(text: "버튼 이름"), size: .m, state: .line),
                onTap: { }
            )
            
            TXButton(
                shape: .rect(style: .basic(text: "버튼 이름"), size: .m, state: .standard),
                onTap: { }
            )
            
            TXButton(
                shape: .rect(style: .basic(text: "버튼 이름"), size: .m, state: .disabled),
                onTap: { }
            )
        }
        
        VStack(alignment: .leading, spacing: Spacing.spacing3) {
            Text("S")
                .font(.headline)
            
            TXButton(
                shape: .rect(style: .basic(text: "버튼 이름"), size: .s, state: .line),
                onTap: { }
            )
            
            TXButton(
                shape: .rect(style: .basic(text: "버튼 이름"), size: .s, state: .standard),
                onTap: { }
            )
        }
    }
    .padding(Spacing.spacing5)
    .frame(maxWidth: .infinity, alignment: .leading)
}
