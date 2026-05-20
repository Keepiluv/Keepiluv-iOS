//
//  StatsCardCompletionCell.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 4/8/26.
//

import SwiftUI

struct StatsCardCompletionCell: View {
    let info: StatsCardItem.CompletionInfo
    let stampIcon: TXVector.Icon
    let goalCount: Int
    let showsStampGrid: Bool
    
    private let columns = Array(
        repeating: GridItem(.flexible()),
        count: Constants.gridColumnCount
    )
    
    var body: some View {
        VStack(spacing: Constants.cellVerticalSpacing) {
            HStack(spacing: 0) {
                Text(info.name)
                    .typography(Constants.infoTypography)
                    .foregroundStyle(Constants.secondaryTextColor)
                
                Spacer()
                
                Text("\(info.count)번 완료")
                    .typography(Constants.infoTypography)
                    .foregroundStyle(Constants.secondaryTextColor)
            }
            
            if showsStampGrid {
                LazyVGrid(columns: columns, spacing: Constants.gridSpacing) {
                    ForEach(0..<goalCount, id: \.self) { count in
                        stampView(at: count)
                    }
                }
            }
        }
        .padding(Constants.cellPadding)
    }
}

private extension StatsCardCompletionCell {
    func stampView(at index: Int) -> some View {
        let appearance = stampAppearance(at: index)
        
        return TXVector(
            icon: stampIcon,
            fillColor: appearance.fillColor,
            borderColor: appearance.borderColor
        )
        .frame(
            width: Constants.iconSize,
            height: Constants.iconSize
        )
    }
    
    func stampAppearance(at index: Int) -> StampAppearance {
        let isCompleted = index < info.count
        let fillColor = isCompleted
        ? info.stampColors.color(at: index) ?? Constants.defaultStampColor
        : .clear
        let borderColor = isCompleted ? Constants.completedStampBorderColor : Constants.incompleteStampBorderColor
        
        return StampAppearance(fillColor: fillColor, borderColor: borderColor)
    }
    
    struct StampAppearance {
        let fillColor: Color
        let borderColor: Color
    }
}

private extension Array where Element == StatsCardItem.StampColor {
    func color(at index: Int) -> Color? {
        guard indices.contains(index) else { return nil }
        return self[index].color
    }
}

private extension StatsCardItem.StampColor {
    var color: Color {
        switch self {
        case .green400:
            return Color.Chromatic.green400
        case .blue400:
            return Color.Chromatic.blue400
        case .yellow400:
            return Color.Chromatic.yellow400
        case .pink400:
            return Color.Chromatic.pink400
        case .pink300:
            return Color.Chromatic.pink300
        case .pink200:
            return Color.Chromatic.pink200
        case .orange400:
            return Color.Chromatic.orange400
        case .purple400:
            return Color.Chromatic.purple400
        }
    }
}

private extension StatsCardCompletionCell {
    enum Constants {
        static let gridColumnCount = 7
        static let cellVerticalSpacing: CGFloat = 12
        static let gridSpacing: CGFloat = 4
        static let iconSize: CGFloat = 18
        static let cellPadding: CGFloat = 16
        static let infoTypography = TypographyToken.b4_12b
        static let secondaryTextColor = Color.Gray.gray400
        static let completedStampBorderColor = Color.Gray.gray500
        static let incompleteStampBorderColor = Color.Gray.gray200
        static let defaultStampColor = Color.Chromatic.blue400
    }
}
