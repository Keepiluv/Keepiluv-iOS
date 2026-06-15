//
//  TXCalendar+Paging.swift
//  SharedDesignSystem
//
//  Created by Codex on 5/30/26.
//

import SwiftUI

// MARK: - Private Methods
extension TXCalendar {
    func calendarSwipeGesture(pageWidth: CGFloat, dayColumnSpacing: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                handleSwipeChanged(value, pageWidth: pageWidth, dayColumnSpacing: dayColumnSpacing)
            }
            .onEnded { value in
                handleSwipeEnded(value, pageWidth: pageWidth, dayColumnSpacing: dayColumnSpacing)
            }
    }

    func handleSwipeChanged(
        _ value: DragGesture.Value,
        pageWidth: CGFloat,
        dayColumnSpacing: CGFloat
    ) {
        let horizontalDistance = value.translation.width
        guard isHorizontalDrag(value.translation) else {
            resetActiveDragTranslation()
            return
        }

        switch mode {
        case .weekly:
            updateWeeklyDragTranslation(
                horizontalDistance,
                pageDistance: weeklyPageDistance(
                    pageWidth: pageWidth,
                    dayColumnSpacing: dayColumnSpacing
                )
            )

        case .monthly:
            updateMonthlyDragTranslation(
                horizontalDistance,
                pageWidth: pageWidth,
                dayColumnSpacing: dayColumnSpacing
            )
        }
    }

    func handleSwipeEnded(
        _ value: DragGesture.Value,
        pageWidth: CGFloat,
        dayColumnSpacing: CGFloat
    ) {
        let horizontalDistance = value.translation.width
        guard isHorizontalDrag(value.translation) else {
            resetActiveDragTranslation()
            return
        }

        let swipe: SwipeGesture = horizontalDistance > 0 ? .previous : .next
        switch mode {
        case .weekly:
            finishWeeklySwipe(
                swipe,
                horizontalDistance: horizontalDistance,
                pageDistance: weeklyPageDistance(
                    pageWidth: pageWidth,
                    dayColumnSpacing: dayColumnSpacing
                )
            )

        case .monthly:
            finishMonthlySwipe(
                swipe,
                horizontalDistance: horizontalDistance,
                pageWidth: pageWidth,
                dayColumnSpacing: dayColumnSpacing
            )
        }
    }

    func isHorizontalDrag(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }

    func updateWeeklyDragTranslation(_ horizontalDistance: CGFloat, pageDistance: CGFloat) {
        guard !isWeeklyPaging else { return }

        withTransaction(Transaction(animation: nil)) {
            weeklyDragTranslation = boundedWeeklyDragTranslation(
                horizontalDistance,
                pageDistance: pageDistance
            )
        }
    }

    func updateMonthlyDragTranslation(
        _ horizontalDistance: CGFloat,
        pageWidth: CGFloat,
        dayColumnSpacing: CGFloat
    ) {
        guard isMonthlyVisualPagingEnabled,
              !isMonthlyPaging else {
            return
        }

        let monthlyPageDistance = pageWidth + monthlyPageSpacing(dayColumnSpacing: dayColumnSpacing)
        withTransaction(Transaction(animation: nil)) {
            if monthlyPagingBaseDate == nil {
                monthlyPagingBaseDate = currentDate?.wrappedValue
            }
            monthlyDragTranslation = boundedMonthlyDragTranslation(
                horizontalDistance,
                pageWidth: monthlyPageDistance
            )
        }
    }

    func finishWeeklySwipe(
        _ swipe: SwipeGesture,
        horizontalDistance: CGFloat,
        pageDistance: CGFloat
    ) {
        handleWeeklySwipe(
            swipe,
            pageDistance: pageDistance,
            releaseTranslation: boundedWeeklyDragTranslation(
                horizontalDistance,
                pageDistance: pageDistance
            )
        )
    }

    func finishMonthlySwipe(
        _ swipe: SwipeGesture,
        horizontalDistance: CGFloat,
        pageWidth: CGFloat,
        dayColumnSpacing: CGFloat
    ) {
        guard isMonthlyVisualPagingEnabled else {
            handleImmediateSwipe(swipe)
            return
        }

        let pageSpacing = monthlyPageSpacing(dayColumnSpacing: dayColumnSpacing)
        let monthlyPageDistance = pageWidth + pageSpacing
        handleMonthlySwipe(
            swipe,
            pageWidth: pageWidth,
            pageSpacing: pageSpacing,
            releaseTranslation: boundedMonthlyDragTranslation(
                horizontalDistance,
                pageWidth: monthlyPageDistance
            )
        )
    }

    func handleWeeklySwipe(
        _ swipe: SwipeGesture,
        pageDistance: CGFloat,
        releaseTranslation: CGFloat
    ) {
        guard canApplySwipe(swipe) else {
            resetWeeklyPagingOffset()
            return
        }

        guard !isWeeklyPaging else { return }

        isWeeklyPaging = true
        let targetDate = weeklyTargetDate(for: swipe)
        withTransaction(Transaction(animation: nil)) {
            weeklyDragTranslation = 0
            weeklyPagingOffset = releaseTranslation
        }

        withAnimation(Self.pagingAnimation) {
            weeklyPagingOffset = pagingTargetOffset(for: swipe, pageDistance: pageDistance)
        } completion: {
            settleWeeklyPaging(to: targetDate)
            applySwipe(swipe, animated: false)
        }
    }

    func handleMonthlySwipe(
        _ swipe: SwipeGesture,
        pageWidth: CGFloat,
        pageSpacing: CGFloat,
        releaseTranslation: CGFloat
    ) {
        guard canApplySwipe(swipe) else {
            resetMonthlyPagingOffset()
            return
        }

        guard !isMonthlyPaging,
              let baseDate = monthlyPagingBaseDate ?? currentDate?.wrappedValue,
              let targetDate = monthlyTargetDate(for: swipe) else {
            return
        }

        isMonthlyPaging = true
        withTransaction(Transaction(animation: nil)) {
            monthlyPagingBaseDate = baseDate
            monthlyDragTranslation = 0
            monthlyPagingOffset = releaseTranslation
        }

        withAnimation(Self.pagingAnimation) {
            monthlyPagingOffset = pagingTargetOffset(for: swipe, pageDistance: pageWidth + pageSpacing)
        } completion: {
            commitMonthlyVisualSwipe(swipe, targetDate: targetDate)
            resetMonthlyPagingOffset()
        }
    }

    func commitMonthlyVisualSwipe(_ swipe: SwipeGesture, targetDate: TXCalendarDate) {
        if let onSwipe {
            onSwipe(swipe)
        } else if let currentDate {
            currentDate.wrappedValue = targetDate
        }
    }

    func handleImmediateSwipe(_ swipe: SwipeGesture) {
        guard canApplySwipe(swipe) else { return }
        applySwipe(swipe, animated: true)
    }

    func canApplySwipe(_ swipe: SwipeGesture) -> Bool {
        switch swipe {
        case .previous:
            return canMovePrevious

        case .next:
            return canMoveNext
        }
    }

    func pagingTargetOffset(for swipe: SwipeGesture, pageDistance: CGFloat) -> CGFloat {
        switch swipe {
        case .previous:
            return pageDistance

        case .next:
            return -pageDistance
        }
    }

    func applySwipe(_ swipe: SwipeGesture, animated: Bool) {
        if let onSwipe {
            if animated {
                withAnimation(Self.pagingAnimation) {
                    onSwipe(swipe)
                }
            } else {
                onSwipe(swipe)
            }
        } else {
            applySwipeToCurrentDate(swipe)
        }
    }

    func settleWeeklyPaging(to targetDate: TXCalendarDate?) {
        withTransaction(Transaction(animation: nil)) {
            weeklyPagingReferenceDate = targetDate
            weeklyDragTranslation = 0
            weeklyPagingOffset = 0
            isWeeklyPaging = false
        }
    }

    func resetWeeklyPagingOffset() {
        withTransaction(Transaction(animation: nil)) {
            weeklyDragTranslation = 0
            weeklyPagingOffset = 0
            isWeeklyPaging = false
        }
    }

    func clearStaleWeeklyPagingReferenceDate() {
        guard let weeklyPagingReferenceDate,
              let weeklyReferenceDate,
              weeklyPagingReferenceDate != weeklyReferenceDate else {
            return
        }

        withTransaction(Transaction(animation: nil)) {
            self.weeklyPagingReferenceDate = nil
        }
    }

    func resetMonthlyPagingOffset() {
        withTransaction(Transaction(animation: nil)) {
            monthlyDragTranslation = 0
            monthlyPagingOffset = 0
            monthlyPagingBaseDate = nil
            isMonthlyPaging = false
        }
    }

    func resetActiveDragTranslation() {
        withTransaction(Transaction(animation: nil)) {
            weeklyDragTranslation = 0
            monthlyDragTranslation = 0
            if !isMonthlyPaging {
                monthlyPagingBaseDate = nil
            }
        }
    }

    func boundedWeeklyDragTranslation(_ translation: CGFloat, pageDistance: CGFloat) -> CGFloat {
        if translation > 0, !canMovePrevious {
            return 0
        }
        if translation < 0, !canMoveNext {
            return 0
        }
        return min(max(translation, -pageDistance), pageDistance)
    }

    func boundedMonthlyDragTranslation(_ translation: CGFloat, pageWidth: CGFloat) -> CGFloat {
        boundedWeeklyDragTranslation(translation, pageDistance: pageWidth)
    }

    func applySwipeToCurrentDate(_ swipe: SwipeGesture) {
        guard let currentDate else { return }

        var updatedDate = currentDate.wrappedValue
        switch mode {
        case .weekly:
            let offset: Int
            switch swipe {
            case .previous:
                offset = -1

            case .next:
                offset = 1
            }
            guard let date = TXCalendarUtil.dateByApplyingWeeklyBoundarySwipe(
                from: updatedDate,
                by: offset
            ) else { return }
            updatedDate = date

        case .monthly:
            switch swipe {
            case .previous:
                updatedDate.goToPreviousMonth()

            case .next:
                updatedDate.goToNextMonth()
            }
        }

        currentDate.wrappedValue = updatedDate
    }
}
