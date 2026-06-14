//
//  CalendarUtil.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 2/6/26.
//

import Foundation

/// 캘린더 관련 공통 유틸리티입니다.
///
/// ## 사용 예시
/// ```swift
/// let date = TXCalendarDate(year: 2026, month: 2, day: 8)
/// let apiDate = TXCalendarUtil.apiDateString(for: date)
/// ```
public enum TXCalendarUtil {
    /// TXCalendarDate를 API 요청용 문자열(YYYY-MM-DD)로 변환합니다.
    public static func apiDateString(for component: TXCalendarDate) -> String {
        component.formattedAPIDateString()
    }
    
    /// API 날짜 문자열(YYYY-MM-DD)을 TXCalendarDate로 변환합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let date = TXCalendarUtil.parseAPIDateString("2026-02-08")
    /// ```
    public static func parseAPIDateString(_ dateString: String) -> TXCalendarDate? {
        let components = dateString.split(separator: "-")
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]) else {
            return nil
        }
        return TXCalendarDate(year: year, month: month, day: day)
    }
    
    /// 기준 날짜에서 주 단위 오프셋만큼 이동한 날짜를 반환합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let today = TXCalendarDate(year: 2026, month: 2, day: 10)
    /// let nextWeek = TXCalendarUtil.dateByAddingWeek(from: today, by: 1)
    /// let previousWeek = TXCalendarUtil.dateByAddingWeek(from: today, by: -1)
    /// ```
    ///
    /// - Parameters:
    ///   - date: 기준 날짜
    ///   - offset: 이동할 주 단위 오프셋 (예: 다음 주 `1`, 이전 주 `-1`)
    /// - Returns: 이동된 날짜. 계산에 실패하면 `nil`을 반환합니다.
    public static func dateByAddingWeek(from date: TXCalendarDate, by offset: Int) -> TXCalendarDate? {
        guard let baseDate = date.date else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        guard let targetDate = calendar.date(byAdding: .weekOfYear, value: offset, to: baseDate) else {
            return nil
        }
        let components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return nil
        }
        return TXCalendarDate(year: year, month: month, day: day)
    }

    /// 주간 캘린더 스와이프 시 경계 요일을 보정한 날짜를 반환합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let sunday = TXCalendarDate(year: 2026, month: 2, day: 8)
    /// let previous = TXCalendarUtil.dateByApplyingWeeklyBoundarySwipe(from: sunday, by: -1)
    /// ```
    ///
    /// 일요일에서 이전으로 이동하면 전날인 토요일로, 토요일에서 다음으로 이동하면 다음 날인 일요일로 이동합니다.
    /// 그 외 날짜는 기존 주 단위 이동과 동일하게 처리합니다.
    public static func dateByApplyingWeeklyBoundarySwipe(
        from date: TXCalendarDate,
        by offset: Int
    ) -> TXCalendarDate? {
        guard let baseDate = date.date else { return nil }

        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: baseDate)
        let dayOffset: Int

        switch (weekday, offset) {
        case (1, let offset) where offset < 0:
            dayOffset = -1

        case (7, let offset) where offset > 0:
            dayOffset = 1

        default:
            return dateByAddingWeek(from: date, by: offset)
        }

        guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: baseDate) else {
            return nil
        }

        let components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return nil
        }
        return TXCalendarDate(year: year, month: month, day: day)
    }
}
