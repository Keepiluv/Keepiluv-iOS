//
//  TXCalendar+Layout.swift
//  SharedDesignSystem
//
//  Created by Codex on 5/30/26.
//

import SwiftUI

// MARK: - Helpers
extension TXCalendar {
    var headerSpacing: CGFloat {
        switch mode {
        case .weekly: config.weeklyHeaderSpacing
        case .monthly: config.monthlyHeaderSpacing
        }
    }

    var horizontalPadding: CGFloat {
        switch mode {
        case .weekly: config.weeklyHorizontalPadding
        case .monthly: config.monthlyHorizontalPadding
        }
    }

    var contentHeight: CGFloat {
        let headerSectionHeight = config.weekdayHeight + headerSpacing
        let verticalPadding: CGFloat = config.verticalPadding * 2

        switch mode {
        case .weekly: return headerSectionHeight + config.dateStyle.size + config.weeklyBottomPadding + verticalPadding
        case .monthly: return headerSectionHeight + monthGridHeight + verticalPadding
        }
    }

    var monthGridHeight: CGFloat {
        guard !weeks.isEmpty else { return 0 }

        let rowCount = max(weeks.count, config.monthlyPaging.minimumRowCount ?? 0)
        let rowSpacing = config.monthlyRowSpacing * CGFloat(max(rowCount - 1, 0))
        return (config.dateStyle.size * CGFloat(rowCount)) + rowSpacing
    }

    var monthlyPageHeight: CGFloat {
        config.weekdayHeight + headerSpacing + monthGridHeight
    }

    var isMonthlyVisualPagingEnabled: Bool {
        mode == .monthly && config.monthlyPaging.isEnabled && currentDate != nil
    }

    static var pagingAnimation: Animation {
        .easeInOut(duration: 0.22)
    }

    func weeklyPageSpacing(dayColumnSpacing: CGFloat) -> CGFloat {
        dayColumnSpacing
    }

    func weeklyPageDistance(pageWidth: CGFloat, dayColumnSpacing: CGFloat) -> CGFloat {
        pageWidth + weeklyPageSpacing(dayColumnSpacing: dayColumnSpacing)
    }

    func monthlyPageSpacing(dayColumnSpacing: CGFloat) -> CGFloat {
        max(config.monthlyPaging.pageSpacing, dayColumnSpacing)
    }

    func monthlyPageDate(monthOffset: Int) -> TXCalendarDate? {
        guard var date = monthlyPagingBaseDate ?? currentDate?.wrappedValue else {
            return nil
        }

        guard monthOffset != 0 else { return date }

        if monthOffset > 0 {
            for _ in 0..<monthOffset {
                date.goToNextMonth()
            }
        } else {
            for _ in 0..<abs(monthOffset) {
                date.goToPreviousMonth()
            }
        }
        return date
    }

    func monthlyPageWeeks(monthOffset: Int) -> [[TXCalendarDateItem]] {
        guard let date = monthlyPageDate(monthOffset: monthOffset) else {
            return weeks
        }

        if monthOffset == 0,
           monthlyPagingBaseDate == nil {
            return weeks
        }

        return config.monthlyPaging.pageWeeks?(date)
            ?? TXCalendarDataGenerator.generateMonthData(for: date)
    }

    func monthlyTargetDate(for swipe: SwipeGesture) -> TXCalendarDate? {
        guard var date = monthlyPagingBaseDate ?? currentDate?.wrappedValue else {
            return nil
        }

        switch swipe {
        case .previous:
            date.goToPreviousMonth()

        case .next:
            date.goToNextMonth()
        }
        return date
    }

    var weekDateItems: [TXCalendarDateItem] {
        weeks.first ?? []
    }

    var activeWeeklyReferenceDate: TXCalendarDate? {
        weeklyPagingReferenceDate ?? weeklyReferenceDate
    }

    func weeklyPageItems(weekOffset: Int) -> [TXCalendarDateItem] {
        if let weeklyPagingReferenceDate {
            guard weekOffset != 0 else {
                return generatedWeeklyPageItems(
                    for: weeklyPagingReferenceDate,
                    weekOffset: 0
                )
            }

            guard let targetDate = weeklyTargetDate(for: weekOffset) else {
                return weekDateItems
            }

            return generatedWeeklyPageItems(
                for: targetDate,
                weekOffset: 0
            )
        }

        guard weekOffset != 0 else {
            return weekDateItems
        }

        guard let targetDate = weeklyTargetDate(for: weekOffset) else {
            return weekDateItems
        }

        return generatedWeeklyPageItems(
            for: targetDate,
            weekOffset: 0
        )
    }

    func generatedWeeklyPageItems(
        for referenceDate: TXCalendarDate,
        weekOffset: Int
    ) -> [TXCalendarDateItem] {
        TXCalendarDataGenerator.generateWeekData(
            for: referenceDate,
            weekOffset: weekOffset
        ).first ?? []
    }

    func weeklyTargetDate(for swipe: SwipeGesture) -> TXCalendarDate? {
        switch swipe {
        case .previous:
            return weeklyTargetDate(for: -1)

        case .next:
            return weeklyTargetDate(for: 1)
        }
    }

    func weeklyTargetDate(for weekOffset: Int) -> TXCalendarDate? {
        guard weekOffset != 0,
              let referenceDate = activeWeeklyReferenceDate else {
            return activeWeeklyReferenceDate
        }

        return TXCalendarUtil.dateByApplyingWeeklyBoundarySwipe(
            from: referenceDate,
            by: weekOffset
        )
    }

    var weeklyReferenceDate: TXCalendarDate? {
        if let currentDate, currentDate.wrappedValue.day != nil {
            return currentDate.wrappedValue
        }

        let selectedItem = weekDateItems.first { item in
            switch item.status {
            case .selectedFilled, .selectedLine:
                return item.dateComponents != nil

            case .completed, .default, .lastDate:
                return false
            }
        }

        if let selectedItem,
           let components = selectedItem.dateComponents {
            return TXCalendarDate(components: components)
        }

        guard let components = weekDateItems.compactMap(\.dateComponents).first else {
            return nil
        }
        return TXCalendarDate(components: components)
    }

    func weeklyHeaderTitle(index: Int, item: TXCalendarDateItem) -> String {
        guard let components = item.dateComponents,
              let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }
        let today = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        let isToday = today.year == year && today.month == month && today.day == day

        return isToday ? "오늘" : weekdays[index]
    }
}
