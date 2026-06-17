//
//  TXCalendarBottomSheet.swift
//  SharedDesignSystem
//
//  Created by Claude on 1/26/26.
//

import SwiftUI

/// 캘린더 바텀시트 컴포넌트입니다.
///
/// ## 기본 사용 예시 (완료 버튼)
/// ```swift
/// TXCalendarBottomSheet(
///     selectedDate: $date,
///     onComplete: { dismiss() }
/// )
/// ```
///
/// ## 커스텀 버튼 사용 예시
/// ```swift
/// TXCalendarBottomSheet(
///     selectedDate: $date
/// ) { exitPickerModeIfNeeded in
///     TXRectGroupButton(
///         leftShape: .rect(style: .basic(text: "취소"), size: .l, state: .line),
///         rightShape: .rect(style: .basic(text: "완료"), size: .l, state: .standard),
///         onTapLeft: { /* 취소 */ },
///         onTapRight: {
///             if !exitPickerModeIfNeeded() { /* 완료 */ }
///         }
///     )
/// }
/// ```
public struct TXCalendarBottomSheet<ButtonContent: View>: View {
    @Binding private var selectedDate: TXCalendarDate
    @State private var isDatePickerMode = false
    @State private var frozenCalendarHeight: CGFloat?
    @State private var calendarData: CalendarPresentationData

    private let buttonContent: (_ exitPickerModeIfNeeded: @escaping () -> Bool) -> ButtonContent
    private let completeButtonText: String?
    private let onComplete: (() -> Void)?
    private let isDateEnabled: ((TXCalendarDateItem) -> Bool)?

    /// 커스텀 버튼을 사용하는 이니셜라이저입니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// TXCalendarBottomSheet(
    ///     selectedDate: $date
    /// ) { exitPickerModeIfNeeded in
    ///     TXRectGroupButton(
    ///         leftShape: .rect(style: .basic(text: "취소"), size: .l, state: .line),
    ///         rightShape: .rect(style: .basic(text: "완료"), size: .l, state: .standard),
    ///         onTapLeft: { /* 취소 */ },
    ///         onTapRight: {
    ///             if !exitPickerModeIfNeeded() { /* 완료 */ }
    ///         }
    ///     )
    /// }
    /// ```
    public init(
        selectedDate: Binding<TXCalendarDate>,
        isDateEnabled: ((TXCalendarDateItem) -> Bool)? = nil,
        @ViewBuilder buttonContent: @escaping (_ exitPickerModeIfNeeded: @escaping () -> Bool) -> ButtonContent
    ) {
        self._selectedDate = selectedDate
        self._calendarData = State(initialValue: Self.makeCalendarData(for: selectedDate.wrappedValue))
        self.buttonContent = buttonContent
        self.completeButtonText = nil
        self.onComplete = nil
        self.isDateEnabled = isDateEnabled
    }

    public var body: some View {
        let currentData = calendarData.matches(selectedDate)
            ? calendarData
            : Self.makeCalendarData(for: selectedDate)
        let displayWeeks = applyDisabledStatus(to: currentData.weeks)
        let currentCalendarHeight = currentData.height

        VStack(spacing: 0) {
            // MonthNavigation + Calendar
            VStack(spacing: Spacing.spacing9) {
                TXCalendarMonthNavigation(
                    title: selectedDate.formattedYearMonth,
                    onTitleTap: {
                        if !isDatePickerMode {
                            frozenCalendarHeight = currentCalendarHeight
                        }
                        isDatePickerMode.toggle()
                    },
                    onPrevious: { updateSelectedDate { $0.goToPreviousMonth() } },
                    onNext: { updateSelectedDate { $0.goToNextMonth() } }
                )
                
                if isDatePickerMode {
                    datePickerView(height: frozenCalendarHeight ?? currentCalendarHeight)
                } else {
                    TXCalendar(
                        mode: .monthly,
                        currentDate: $selectedDate,
                        weeks: displayWeeks,
                        config: calendarConfig
                    ) { item in
                        if let day = Int(item.text), item.status != .lastDate {
                            updateSelectedDate { $0.selectDay(day) }
                        }
                    }
                }
            }
            .padding(.bottom, 40)

            // 버튼 영역
            buttonArea
        }
        .frame(maxWidth: .infinity)
        .background(Color.Common.white)
        .overlay {
            Color.clear
                .accessibilityIdentifier("tx.calendar-bottom-sheet")
                .allowsHitTesting(false)
        }
        .onChange(of: isDatePickerMode) { _, newValue in
            if !newValue {
                frozenCalendarHeight = nil
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            updateCalendarData(for: newValue)
        }
    }
}

// MARK: - Default Button Initializer
public extension TXCalendarBottomSheet where ButtonContent == DefaultCalendarButton {
    /// 기본 완료 버튼을 사용하는 이니셜라이저
    ///
    /// ## 사용 예시
    /// ```swift
    /// TXCalendarBottomSheet(
    ///     selectedDate: $date,
    ///     completeButtonText: "완료",
    ///     onComplete: { dismiss() }
    /// )
    /// ```
    init(
        selectedDate: Binding<TXCalendarDate>,
        completeButtonText: String = "완료",
        onComplete: @escaping () -> Void,
        isDateEnabled: ((TXCalendarDateItem) -> Bool)? = nil
    ) {
        self._selectedDate = selectedDate
        self._calendarData = State(initialValue: Self.makeCalendarData(for: selectedDate.wrappedValue))
        self.buttonContent = { _ in
            DefaultCalendarButton(text: completeButtonText, action: onComplete)
        }
        self.completeButtonText = completeButtonText
        self.onComplete = onComplete
        self.isDateEnabled = isDateEnabled
    }
}

/// 기본 완료 버튼 뷰
public struct DefaultCalendarButton: View {
    let text: String
    let action: () -> Void

    public var body: some View {
        TXButton(
            shape: .rect(
                style: .basic(text: text),
                size: .l,
                state: .standard
            ),
            onTap: action
        )
        .padding(.horizontal, Spacing.spacing8)
        .accessibilityIdentifier("tx.calendar-bottom-sheet.complete-button")
    }
}

// MARK: - Private Views
private extension TXCalendarBottomSheet {
    static var minimumMonthlyRowCount: Int { 6 }

    static var calendarConfig: TXCalendar.Configuration {
        .init(
            monthlyHeaderSpacing: Spacing.spacing7,
            monthlyRowSpacing: Spacing.spacing6,
            monthlyPaging: .init(minimumRowCount: minimumMonthlyRowCount)
        )
    }

    var calendarConfig: TXCalendar.Configuration {
        let isDateEnabled = isDateEnabled
        return .init(
            monthlyHeaderSpacing: Spacing.spacing7,
            monthlyRowSpacing: Spacing.spacing6,
            monthlyPaging: .init(
                isEnabled: true,
                pageSpacing: Spacing.spacing7,
                minimumRowCount: Self.minimumMonthlyRowCount,
                pageWeeks: { date in
                    let weeks = Self.makeCalendarData(for: date).weeks
                    return Self.applyDisabledStatus(
                        to: weeks,
                        isDateEnabled: isDateEnabled
                    )
                }
            )
        )
    }

    static func makeCalendarData(for date: TXCalendarDate) -> CalendarPresentationData {
        let weeks = TXCalendarDataGenerator.generateMonthData(for: date)
        return CalendarPresentationData(
            key: .init(date),
            weeks: weeks,
            height: calendarContentHeight(for: weeks)
        )
    }

    static func calendarContentHeight(for weeks: [[TXCalendarDateItem]]) -> CGFloat {
        let config = calendarConfig
        let headerHeight = TXCalendarLayout.weekdayLabelHeight(config.weekdayTypography)
        let headerSectionHeight = headerHeight + config.monthlyHeaderSpacing
        let verticalPadding = config.verticalPadding * 2

        guard !weeks.isEmpty else { return headerSectionHeight + verticalPadding }

        let rowCount = max(weeks.count, Self.minimumMonthlyRowCount)
        let rowSpacing = config.monthlyRowSpacing * CGFloat(max(rowCount - 1, 0))
        let monthGridHeight = (config.dateStyle.size * CGFloat(rowCount)) + rowSpacing

        return headerSectionHeight + monthGridHeight + verticalPadding
    }

    @ViewBuilder
    var buttonArea: some View {
        if let completeButtonText, let onComplete {
            DefaultCalendarButton(text: completeButtonText) {
                if isDatePickerMode {
                    isDatePickerMode = false
                } else {
                    onComplete()
                }
            }
        } else {
            buttonContent(exitPickerModeIfNeeded)
        }
    }

    func exitPickerModeIfNeeded() -> Bool {
        if isDatePickerMode {
            isDatePickerMode = false
            return true
        }
        return false
    }

    func datePickerView(height: CGFloat) -> some View {
        HStack(spacing: 0) {
            Picker("Year", selection: selectedYear) {
                ForEach(1_940...2_099, id: \.self) { year in
                    Text(verbatim: "\(year)년").tag(year)
                }
            }
            .pickerStyle(.wheel)

            Picker("Month", selection: selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(verbatim: "\(month)월").tag(month)
                }
            }
            .pickerStyle(.wheel)
        }
        .frame(height: height)
        .padding(.horizontal, Spacing.spacing7)
    }

    var selectedYear: Binding<Int> {
        Binding(
            get: { selectedDate.year },
            set: { year in
                updateSelectedDate { date in
                    date.year = year
                }
            }
        )
    }

    var selectedMonth: Binding<Int> {
        Binding(
            get: { selectedDate.month },
            set: { month in
                updateSelectedDate { date in
                    date.month = month
                }
            }
        )
    }

    func updateSelectedDate(_ update: (inout TXCalendarDate) -> Void) {
        var newDate = selectedDate
        update(&newDate)
        selectedDate = newDate
        updateCalendarData(for: newDate)
    }

    func updateCalendarData(for date: TXCalendarDate) {
        guard !calendarData.matches(date) else { return }
        calendarData = Self.makeCalendarData(for: date)
    }

    func applyDisabledStatus(to weeks: [[TXCalendarDateItem]]) -> [[TXCalendarDateItem]] {
        Self.applyDisabledStatus(
            to: weeks,
            isDateEnabled: isDateEnabled
        )
    }

    static func applyDisabledStatus(
        to weeks: [[TXCalendarDateItem]],
        isDateEnabled: ((TXCalendarDateItem) -> Bool)?
    ) -> [[TXCalendarDateItem]] {
        guard let isDateEnabled else { return weeks }
        return weeks.map { week in
            week.map { item in
                guard item.status != .lastDate else { return item }
                if isDateEnabled(item) { return item }
                return TXCalendarDateItem(
                    id: item.id,
                    text: item.text,
                    status: .lastDate,
                    dateComponents: item.dateComponents
                )
            }
        }
    }
}

private struct CalendarPresentationData: Equatable {
    struct Key: Equatable {
        let year: Int
        let month: Int
        let day: Int?

        init(_ date: TXCalendarDate) {
            self.year = date.year
            self.month = date.month
            self.day = date.day
        }
    }

    let key: Key
    let weeks: [[TXCalendarDateItem]]
    let height: CGFloat

    func matches(_ date: TXCalendarDate) -> Bool {
        key == Key(date)
    }
}
