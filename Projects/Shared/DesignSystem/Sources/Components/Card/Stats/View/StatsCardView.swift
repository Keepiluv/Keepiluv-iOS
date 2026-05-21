//
//  StatsCardView.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 2/18/26.
//

import SwiftUI

/// 목표별 스탬프 통계 정보를 카드 형태로 보여주는 컴포넌트입니다.
///
/// ## 사용 예시
/// ```swift
/// StatsCardView(
///     item: item,
///     isOngoing: true,
///     onTap: { goalId in
///         print(goalId)
///     }
/// )
/// ```
public struct StatsCardView: View {
    
    private let item: StatsCardItem
    private let isOngoing: Bool
    private var onTap: (Int64) -> Void
    
    /// 통계 카드 구성값과 탭 액션을 받아 컴포넌트를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let view = StatsCardView(
    ///     item: item,
    ///     isOngoing: false,
    ///     onTap: { _ in }
    /// )
    /// ```
    public init(
        item: StatsCardItem,
        isOngoing: Bool,
        onTap: @escaping (Int64) -> Void
    ) {
        self.item = item
        self.isOngoing = isOngoing
        self.onTap = onTap
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            header
            verticalDivider
            completionSection
        }
        .clipShape(RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
        .outsideBorder(
            Color.Gray.gray500,
            shape: RoundedRectangle(cornerRadius: Constants.cardCornerRadius),
            lineWidth: Constants.borderLineWidth
        )
        .onTapGesture { onTap(item.goalId) }
    }
}

// MARK: - SubViews
private extension StatsCardView {
    var header: some View {
        CardHeaderView(
            title: item.goalName,
            iconImage: item.iconImage,
            isBordered: false,
            onTap: { onTap(item.goalId) },
            rightContent: {
                Text(headerSummaryText)
                    .typography(Constants.headerTypography)
            }
        )
    }
    
    var verticalDivider: some View {
        Constants.borderColor
            .frame(maxWidth: .infinity, maxHeight: Constants.borderLineWidth)
            .padding(.bottom, -1)
    }
    
    var completionSection: some View {
        HStack(spacing: 0) {
            ForEach(Array(item.completionInfos.enumerated()), id: \.offset) { index, info in
                StatsCardCompletionCell(
                    info: info,
                    stampIcon: item.stampIcon,
                    goalCount: item.goalCount,
                    showsStampGrid: isOngoing
                )
                    .overlay(alignment: .trailing) {
                        if index < item.completionInfos.count - 1 {
                            horizontalDivider
                        }
                    }
            }
        }
        .background(Constants.backgroundColor)
    }
    
    var horizontalDivider: some View {
        Constants.borderColor
            .frame(width: Constants.borderLineWidth)
    }

    var headerSummaryText: String {
        let statusPrefix = isOngoing ? Constants.ongoingStatusPrefix : Constants.totalStatusPrefix
        return "\(statusPrefix) 목표 \(item.goalCount)번"
    }
}

// MARK: - Constants
private extension StatsCardView {
    enum Constants {
        static let cardCornerRadius: CGFloat = 12
        static let borderLineWidth: CGFloat = 1
        static let headerTypography = TypographyToken.b1_14b
        static let borderColor = Color.Gray.gray500
        static let backgroundColor = Color.Common.white
        static let ongoingStatusPrefix = "이번달"
        static let totalStatusPrefix = "총"
    }
}

#Preview {
    VStack {
        StatsCardView(
            item: .init(
                goalId: 1,
                goalName: "목표이름",
                iconImage: .Icon.Illustration.book,
                stampIcon: .clover,
                goalCount: 30,
                completionInfos: [
                    .init(name: "민정", count: 10, stampColors: [.green400, .blue400]),
                    .init(name: "현수", count: 20, stampColors: [.pink400, .orange400])
                ]
            ),
            isOngoing: true,
            onTap: { _ in }
        )
        
        StatsCardView(
            item: .init(
                goalId: 2,
                goalName: "목표이름",
                iconImage: .Icon.Illustration.book,
                stampIcon: .flower,
                goalCount: 20,
                completionInfos: [
                    .init(name: "민정", count: 3, stampColors: []),
                    .init(name: "현수", count: 10, stampColors: [])
                ]
            ),
            isOngoing: false,
            onTap: { _ in }
        )
    }
    .padding(.horizontal, 20)
}
