//
//  TXCalendar.swift
//  SharedDesignSystem
//
//  Created by 정지용 on 1/22/26.
//

import SwiftUI

/// 주간/월간 그리드를 제공하는 캘린더 컴포넌트입니다.
///
/// ## 사용 예시
/// ```swift
/// TXCalendar(
///     mode: .monthly,
///     weeks: weeks
/// ) { item in
///     print(item.dateComponents as Any)
/// }
/// ```
public struct TXCalendar: View {
    /// 캘린더 표시 모드입니다.
    public enum DisplayMode {
        case weekly
        case monthly
    }

    /// 캘린더 스와이프 방향입니다.
    public enum SwipeGesture {
        case previous
        case next
    }
    
    /// 캘린더 레이아웃 설정입니다.
    public struct Configuration {
        /// 월간 캘린더 페이징 설정입니다.
        public struct MonthlyPagingConfiguration {
            let isEnabled: Bool
            let pageSpacing: CGFloat
            let minimumRowCount: Int?
            let pageWeeks: ((TXCalendarDate) -> [[TXCalendarDateItem]])?

            public static let disabled = Self()

            public init(
                isEnabled: Bool = false,
                pageSpacing: CGFloat = 0,
                minimumRowCount: Int? = nil,
                pageWeeks: ((TXCalendarDate) -> [[TXCalendarDateItem]])? = nil
            ) {
                self.isEnabled = isEnabled
                self.pageSpacing = pageSpacing
                self.minimumRowCount = minimumRowCount
                self.pageWeeks = pageWeeks
            }
        }

        let weeklyHorizontalPadding: CGFloat
        let monthlyHorizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let weeklyHeaderSpacing: CGFloat
        let weeklyBottomPadding: CGFloat
        let monthlyHeaderSpacing: CGFloat
        let monthlyRowSpacing: CGFloat
        let weekdayHeight: CGFloat
        let weekdayTypography: TypographyToken
        let weekdayColor: Color
        let backgroundColor: Color
        let dateStyle: TXCalendarDateStyle
        let dateCellBackground: ((TXCalendarDateItem) -> AnyView?)?
        let monthlyPaging: MonthlyPagingConfiguration
        
        /// 캘린더 레이아웃 설정을 생성합니다.
        public init(
            weeklyHorizontalPadding: CGFloat = Spacing.spacing6,
            monthlyHorizontalPadding: CGFloat = Spacing.spacing7,
            verticalPadding: CGFloat = Spacing.spacing3,
            weeklyHeaderSpacing: CGFloat = Spacing.spacing4,
            weeklyBottomPadding: CGFloat = Spacing.spacing5,
            monthlyHeaderSpacing: CGFloat = Spacing.spacing8,
            monthlyRowSpacing: CGFloat = Spacing.spacing6,
            weekdayHeight: CGFloat = 18,
            weekdayTypography: TypographyToken = .c1_12r,
            weekdayColor: Color = Color.Gray.gray300,
            backgroundColor: Color = Color.Common.white,
            dateStyle: TXCalendarDateStyle = .init(),
            dateCellBackground: ((TXCalendarDateItem) -> AnyView?)? = nil,
            monthlyPaging: MonthlyPagingConfiguration = .disabled
        ) {
            self.weeklyHorizontalPadding = weeklyHorizontalPadding
            self.monthlyHorizontalPadding = monthlyHorizontalPadding
            self.verticalPadding = verticalPadding
            self.weeklyHeaderSpacing = weeklyHeaderSpacing
            self.weeklyBottomPadding = weeklyBottomPadding
            self.monthlyHeaderSpacing = monthlyHeaderSpacing
            self.monthlyRowSpacing = monthlyRowSpacing
            self.weekdayHeight = weekdayHeight
            self.weekdayTypography = weekdayTypography
            self.weekdayColor = weekdayColor
            self.backgroundColor = backgroundColor
            self.dateStyle = dateStyle
            self.dateCellBackground = dateCellBackground
            self.monthlyPaging = monthlyPaging
        }
    }
    
    public static let defaultWeekdays = ["일", "월", "화", "수", "목", "금", "토"]
    
    let mode: DisplayMode
    let weekdays: [String]
    let weeks: [[TXCalendarDateItem]]
    let currentDate: Binding<TXCalendarDate>?
    let canMovePrevious: Bool
    let canMoveNext: Bool
    let config: Configuration
    let onSelect: (TXCalendarDateItem) -> Void
    let onSwipe: ((SwipeGesture) -> Void)?
    // Split TXCalendar paging helpers live in same module extension files.
    // swiftlint:disable private_swiftui_state
    @State var weeklyDragTranslation: CGFloat = 0
    @State var weeklyPagingOffset: CGFloat = 0
    @State var weeklyPagingReferenceDate: TXCalendarDate?
    @State var isWeeklyPaging = false
    @State var monthlyDragTranslation: CGFloat = 0
    @State var monthlyPagingOffset: CGFloat = 0
    @State var monthlyPagingBaseDate: TXCalendarDate?
    @State var isMonthlyPaging = false
    // swiftlint:enable private_swiftui_state
    
    /// 캘린더 컴포넌트를 생성합니다.
    public init(
        mode: DisplayMode,
        weeks: [[TXCalendarDateItem]],
        weekdays: [String] = Self.defaultWeekdays,
        canMovePrevious: Bool = true,
        canMoveNext: Bool = true,
        config: Configuration = .init(),
        onSelect: @escaping (TXCalendarDateItem) -> Void = { _ in },
        onSwipe: ((SwipeGesture) -> Void)? = nil
    ) {
        self.mode = mode
        self.weeks = weeks
        self.weekdays = Array(weekdays.prefix(TXCalendarLayout.daysInWeek))
        self.config = config
        self.currentDate = nil
        self.canMovePrevious = canMovePrevious
        self.canMoveNext = canMoveNext
        self.onSelect = onSelect
        self.onSwipe = onSwipe
    }

    /// 현재 날짜 바인딩을 포함한 캘린더 컴포넌트를 생성합니다.
    public init(
        mode: DisplayMode,
        currentDate: Binding<TXCalendarDate>,
        weeks: [[TXCalendarDateItem]],
        weekdays: [String] = Self.defaultWeekdays,
        config: Configuration = .init(),
        canMovePrevious: Bool = true,
        canMoveNext: Bool = true,
        onSelect: @escaping (TXCalendarDateItem) -> Void = { _ in },
        onSwipe: ((SwipeGesture) -> Void)? = nil
    ) {
        self.mode = mode
        self.weeks = weeks
        self.weekdays = Array(weekdays.prefix(TXCalendarLayout.daysInWeek))
        self.config = config
        self.currentDate = currentDate
        self.canMovePrevious = canMovePrevious
        self.canMoveNext = canMoveNext
        self.onSelect = onSelect
        self.onSwipe = onSwipe
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let spacing = TXCalendarLayout.columnSpacing(
                availableWidth: proxy.size.width,
                horizontalPadding: horizontalPadding,
                cellSize: config.dateStyle.size,
                columns: TXCalendarLayout.daysInWeek
            )
            let pageWidth = max(0, proxy.size.width - (horizontalPadding * 2))

            staticCalendarContent(
                width: proxy.size.width,
                spacing: spacing
            )
            .transaction { transaction in
                if isWeeklyPaging || isMonthlyPaging {
                    transaction.disablesAnimations = false
                    transaction.animation = Self.pagingAnimation
                }
            }
            .highPriorityGesture(
                calendarSwipeGesture(
                    pageWidth: pageWidth,
                    dayColumnSpacing: spacing
                )
            )
        }
        .frame(height: contentHeight)
        .onChange(of: weeks) { _, _ in
            clearStaleWeeklyPagingReferenceDate()
        }
    }
}

// MARK: - SubViews
private extension TXCalendar {
    func staticCalendarContent(width: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: headerSpacing) {
            switch mode {
            case .weekly:
                weeklyPageContent(
                    width: max(0, width - (horizontalPadding * 2)),
                    spacing: spacing
                )

            case .monthly:
                if isMonthlyVisualPagingEnabled {
                    monthlyPageContent(
                        width: max(0, width - (horizontalPadding * 2)),
                        spacing: spacing
                    )
                } else {
                    monthlyWeekdayRow(spacing: spacing)
                    monthGrid(weeks: weeks, spacing: spacing)
                }
            }
        }
        .padding(.vertical, config.verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(width: width, height: contentHeight, alignment: .top)
        .background(config.backgroundColor)
    }

    func weeklyPageContent(width: CGFloat, spacing: CGFloat) -> some View {
        let pageSpacing = weeklyPageSpacing(dayColumnSpacing: spacing)
        return HStack(spacing: pageSpacing) {
            weeklyPage(items: weeklyPageItems(weekOffset: -1), spacing: spacing)
                .frame(width: width)
            weeklyPage(items: weeklyPageItems(weekOffset: 0), spacing: spacing)
                .frame(width: width)
            weeklyPage(items: weeklyPageItems(weekOffset: 1), spacing: spacing)
                .frame(width: width)
        }
        .offset(x: -(width + pageSpacing) + weeklyPagingOffset + weeklyDragTranslation)
        .frame(
            width: width,
            height: config.weekdayHeight + headerSpacing + config.dateStyle.size + config.weeklyBottomPadding,
            alignment: .leading
        )
        .clipped()
    }

    func monthlyPageContent(width: CGFloat, spacing: CGFloat) -> some View {
        let pageSpacing = monthlyPageSpacing(dayColumnSpacing: spacing)
        return HStack(spacing: pageSpacing) {
            monthlyPage(weeks: monthlyPageWeeks(monthOffset: -1), spacing: spacing)
                .frame(width: width, height: monthlyPageHeight, alignment: .top)
            monthlyPage(weeks: monthlyPageWeeks(monthOffset: 0), spacing: spacing)
                .frame(width: width, height: monthlyPageHeight, alignment: .top)
            monthlyPage(weeks: monthlyPageWeeks(monthOffset: 1), spacing: spacing)
                .frame(width: width, height: monthlyPageHeight, alignment: .top)
        }
        .offset(x: -(width + pageSpacing) + monthlyPagingOffset + monthlyDragTranslation)
        .frame(width: width, height: monthlyPageHeight, alignment: .leading)
        .clipped()
    }

    func monthlyPage(weeks: [[TXCalendarDateItem]], spacing: CGFloat) -> some View {
        VStack(spacing: headerSpacing) {
            monthlyWeekdayRow(spacing: spacing)
            monthGrid(weeks: weeks, spacing: spacing)
        }
        .frame(height: monthlyPageHeight, alignment: .top)
    }

    func weeklyPage(items: [TXCalendarDateItem], spacing: CGFloat) -> some View {
        VStack(spacing: headerSpacing) {
            weekdayRow(items: items, spacing: spacing)
            weekRow(items: items, spacing: spacing)
        }
    }

    func weekdayRow(items: [TXCalendarDateItem], spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Text(weeklyHeaderTitle(index: index, item: item))
                    .typography(config.weekdayTypography)
                    .foregroundStyle(config.weekdayColor)
                    .frame(width: config.dateStyle.size, height: config.weekdayHeight)
            }
        }
    }

    func monthlyWeekdayRow(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(weekdays, id: \.self) { weekday in
                Text(weekday)
                    .typography(config.weekdayTypography)
                    .foregroundStyle(config.weekdayColor)
                    .frame(width: config.dateStyle.size, height: config.weekdayHeight)
            }
        }
    }

    func weekRow(items: [TXCalendarDateItem], spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                dateButton(for: item)
            }
        }
    }

    func monthGrid(weeks: [[TXCalendarDateItem]], spacing: CGFloat) -> some View {
        Grid(
            horizontalSpacing: spacing,
            verticalSpacing: config.monthlyRowSpacing
        ) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                GridRow {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, item in
                        dateButton(for: item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func dateButton(for item: TXCalendarDateItem) -> some View {
        let customBackground = config.dateCellBackground?(item)
        Button {
            onSelect(item)
        } label: {
            TXCalendarDateCell(
                item: item,
                style: config.dateStyle,
                customBackground: customBackground
            )
        }
        .buttonStyle(.plain)
    }
}
