//
//  TXRoundButton.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 1/15/26.
//

import SwiftUI

struct TXRoundButton: View {
    let shape: TXButtonShape
    let onTap: () -> Void
    
    public var body: some View {
        if case let .round(style, size, state) = shape {
            Button {
                onTap()
            } label: {
                ZStack {
                    Capsule()
                        .fill(style.backgroundColor(state: state))
                        .frame(maxWidth: size.frameWidth)
                        .frame(height: size.backgroundHeight(state: state))
                        .padding(.top, size.bottomYOffset(state: state))
                    
                    Text(style.text)
                        .typography(size.typography)
                        .foregroundStyle(style.fontColor(state: state))
                        .frame(maxWidth: size.frameWidth)
                        .frame(height: size.foregroundHeight)
                        .insideBorder(
                            style.borderColor(state: state),
                            shape: .capsule,
                            lineWidth: size.borderWidth
                        )
                        .background(style.foregroundColor(state: state), in: .capsule)
                }
                .padding(.top, size.topYOffset(state: state))
            }
            .buttonStyle(.plain)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Constants
private extension TXButtonShape.TXRoundStyle {
    var text: String {
        switch self {
        case let .illustLight(text), let .lillustDark(text): text
        }
    }
    
    func foregroundColor(state: TXButtonShape.TXRoundState) -> Color {
        switch (self, state) {
        case (.illustLight, .standard): Color.Common.white
        case (.lillustDark, .standard): Color.Gray.gray500
        case (.illustLight, .disabled): Color.Gray.gray50
        case (.lillustDark, .disabled): .clear
        }
    }
    
    func backgroundColor(state: TXButtonShape.TXRoundState) -> Color {
        switch (self, state) {
        case (.illustLight, .standard): Color.Gray.gray500
        case (.lillustDark, .standard): Color.Common.white
        case (.illustLight, .disabled): Color.Gray.gray200
        case (.lillustDark, .disabled): .clear
        }
    }
    
    func fontColor(state: TXButtonShape.TXRoundState) -> Color {
        switch (self, state) {
        case (.illustLight, .standard): Color.Gray.gray500
        case (.lillustDark, .standard): Color.Common.white
        case (.illustLight, .disabled): Color.Gray.gray200
        case (.lillustDark, .disabled): .clear
        }
    }
    
    func borderColor(state: TXButtonShape.TXRoundState) -> Color {
        switch (self, state) {
        case (.illustLight, .standard): Color.Gray.gray500
        case (.lillustDark, .standard): Color.Common.white
        case (.illustLight, .disabled): Color.Gray.gray200
        case (.lillustDark, .disabled): .clear
        }
    }
}

private extension TXButtonShape.TXRoundSize {
    var typography: TypographyToken {
        switch self {
        case .l, .m: .t2_16b
        case .s: .c2_11b
        }
    }
    
    var frameWidth: CGFloat {
        switch self {
        case .l: .infinity
        case .m: 150
        case .s: 64
        }
    }
    
    var foregroundHeight: CGFloat {
        switch self {
        case .l, .m: 68
        case .s: 28
        }
    }
    
    func backgroundHeight(state: TXButtonShape.TXRoundState) -> CGFloat {
        switch self {
        case .l, .m: 70
            
        case .s:
            switch state {
            case .standard: 31
            case .disabled: 28
            }
        }
    }
    
    func bottomYOffset(state: TXButtonShape.TXRoundState) -> CGFloat {
        switch self {
        case .s, .l, .m:
            switch state {
            case .standard: 4
            case .disabled: 1
            }
        }
    }
    
    func topYOffset(state: TXButtonShape.TXRoundState) -> CGFloat {
        switch self {
        case .s, .l, .m:
            switch state {
            case .standard: 0
            case .disabled: 3
            }
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .l, .m: 1.6
        case .s: 1
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.spacing7) {
        Text("Round")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: Spacing.spacing3) {
            TXButton(
                shape: .round(
                    style: .illustLight(text: "버튼 이름"),
                    size: .l,
                    state: .standard
                ),
                onTap: { }
            )
            
            TXButton(
                shape: .round(
                    style: .lillustDark(text: "버튼 이름"),
                    size: .l,
                    state: .standard
                ),
                onTap: { }
            )
        }
        
        HStack(spacing: Spacing.spacing5) {
            TXButton(
                shape: .round(
                    style: .illustLight(text: "중간 버튼"),
                    size: .m,
                    state: .standard
                ),
                onTap: { }
            )
            
            TXButton(
                shape: .round(
                    style: .lillustDark(text: "중간 버튼"),
                    size: .m,
                    state: .standard
                ),
                onTap: { }
            )
        }
        
        HStack(spacing: Spacing.spacing5) {
            TXButton(
                shape: .round(
                    style: .illustLight(text: "작게"),
                    size: .s,
                    state: .standard
                ),
                onTap: { }
            )
            
            TXButton(
                shape: .round(
                    style: .lillustDark(text: "작게"),
                    size: .s,
                    state: .standard
                ),
                onTap: { }
            )
        }
    }
    .padding(Spacing.spacing5)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color.Gray.gray200)
}
