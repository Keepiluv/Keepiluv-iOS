//
//  TopTabBar.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 1/18/26.
//

import SwiftUI

/// 상단 탭 전환을 제공하는 컴포넌트입니다.
///
/// ## 사용 예시
/// ```swift
/// enum TopTabItem: String, TXItem {
///     case first
///     case second
///
///     var title: String { rawValue }
/// }
///
/// TXTab(style: .line(TopTabItem.allCases), selectedItem: .first) { item in print(item) }
/// ```
struct TXTopTabBar<Item: TXItem>: View {
    private let selectedItem: Item?
    private let items: [Item]
    private let onSelect: (Item) -> Void
    
    init(
        items: [Item],
        selectedItem: Item? = nil,
        onSelect: @escaping (Item) -> Void = { _ in }
    ) {
        self.selectedItem = selectedItem
        self.items = items
        self.onSelect = onSelect
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    tabItem(item: item, isSelected: selectedItem == item)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - SubViews
private extension TXTopTabBar {
    func tabItem(item: Item, isSelected: Bool) -> some View {
        Text(item.title)
            .typography(Constants.font)
            .foregroundStyle(isSelected ? Constants.selectedColor : Constants.unselectedColor)
            .padding(.bottom, Constants.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: Constants.height)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .foregroundStyle(isSelected ? Constants.selectedColor : Constants.unselectedUnderlineColor)
                    .frame(height: Constants.underlineHeight)
            }
    }
}

// MARK: - Constants
private enum Constants {
    static let font: TypographyToken = .t2_16b
    static let selectedColor: Color = Color.Gray.gray500
    static let unselectedColor: Color = Color.Gray.gray200
    static let unselectedUnderlineColor: Color = Color.Gray.gray100
    static let height: CGFloat = 36
    static let bottomPadding: CGFloat = Spacing.spacing6
    static let underlineHeight: CGFloat = LineWidth.l
}

#Preview {
    VStack {
        TXTopTabBar(
            items: PreviewTopTabItem.allCases,
            selectedItem: .first
        )
        
        Spacer()
    }
}

private enum PreviewTopTabItem: String, TXItem {
    case first = "first"
    case second = "second"

    var title: String { rawValue }
}
