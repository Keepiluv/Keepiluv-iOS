//
//  TXTabBar.swift
//  SharedDesignSystem
//
//  Created by 정지용 on 1/22/26.
//

import SwiftUI

/// 하단 탭바 컴포넌트입니다.
/// - Note: 외부에서 직접 사용하지 않고 `TXTabBarContainer`를 통해 사용합니다.
struct TXTabBar: View {
    @Binding private var selectedItem: TXTabItem

    init(selectedItem: Binding<TXTabItem>) {
        self._selectedItem = selectedItem
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(TXTabItem.visibleCases, id: \.rawValue) { item in
                    tabItemView(item: item)
                }
            }
            .frame(height: Constants.tabBarHeight)
            .background(Constants.backgroundColor)
            .insideRectEdgeBorder(
                width: Constants.borderWidth,
                edges: [.top],
                color: Constants.borderColor
            )
        }
    }
}

// MARK: - SubViews
private extension TXTabBar {
    func tabItemView(item: TXTabItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            VStack(spacing: Constants.iconLabelSpacing) {
                item.icon(isSelected: selectedItem == item)
                    .resizable()
                    .frame(width: Constants.iconSize, height: Constants.iconSize)

                Text(item.title)
                    .typography(Constants.labelFont)
                    .foregroundStyle(Constants.labelColor)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.top, Constants.topPadding)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tx.tab-bar.item.\(item.accessibilityIdentifier)")
    }
}

// MARK: - Constants
private extension TXTabBar {
    enum Constants {
        static let tabBarHeight: CGFloat = 58
        static let iconSize: CGFloat = 24
        static let iconLabelSpacing: CGFloat = 4
        static let topPadding: CGFloat = 12
        static let borderWidth: CGFloat = LineWidth.m
        static let backgroundColor: Color = Color.Common.white
        static let borderColor: Color = Color.Gray.gray100
        static let labelColor: Color = Color.Gray.gray500
        static let labelFont: TypographyToken = .c2_11b
    }
}

private extension TXTabItem {
    var accessibilityIdentifier: String {
        switch self {
        case .home:
            return "home"

        case .statistics:
            return "statistics"

        case .couple:
            return "couple"
        }
    }
}
