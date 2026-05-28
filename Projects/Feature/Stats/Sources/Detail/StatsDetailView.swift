//
//  StatsDetailView.swift
//  FeatureStats
//
//  Created by 정지훈 on 2/19/26.
//

import SwiftUI

import ComposableArchitecture
import FeatureCommonInterface
import FeatureStatsInterface
import SharedDesignSystem
import Kingfisher

struct StatsDetailView: View {
    
    @Bindable var store: StoreOf<StatsDetailReducer>
    
    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            
            ScrollView {
                VStack(spacing: 0) {
                    monthNavigation
                        .padding(.top, 24)
                    calendar
                        .padding(.top, 12)
                    statsInfoContent
                        .padding(.top, 44)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.Gray.gray50)
        .overlay(alignment: .topTrailing) {
            if store.isDropdownPresented {
                TXDropdown(
                    items: GoalDropList.allCases,
                    onSelect: { item in
                        store.send(.view(.dropDownSelected(item)))
                    }
                )
                .offset(x: -12, y: 65)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            store.send(.view(.onAppear))
        }
        .onDisappear {
            store.send(.view(.onDisappear))
        }
        .onTapGesture {
            guard store.isDropdownPresented else { return }
            store.send(.view(.backgroundTapped))
        }
        .txModal(item: $store.modal) { action in
            if action == .confirm {
                store.send(.view(.modalConfirmTapped))
            }
        }
        .txToast(item: $store.toast)
        .txLoading(isPresented: store.isLoading)
    }
}

// MARK: - SubViews
private extension StatsDetailView {
    var navigationBar: some View {
        TXNavigationBar(
            style: .subContent(
                .init(
                    title: store.naviBarTitle,
                    rightContent: store.isCompleted
                        ? .text("삭제")
                        : .rotatedImage(Image.Icon.Symbol.meatball, angle: .degrees(90)),
                    backgroundColor: Color.Gray.gray50
                )
            ),
            onAction: { action in
                store.send(.view(.navigationBarTapped(action)))
            }
        )
    }
    
    var monthNavigation: some View {
        TXCalendarMonthNavigation(
            title: store.currentMonthTitle,
            isPreviousDisabled: store.previousMonthDisabled,
            isNextDisabled: store.nextMonthDisabled,
            onPrevious: { store.send(.view(.previousMonthTapped)) },
            onNext: { store.send(.view(.nextMonthTapped)) }
        )
    }
    
    var calendar: some View {
        // FIXME: - 피그마 컴포넌트에 있는 Calendar랑 값이 다른 부분이 좀 있어서 리팩터링할 때 참고 바람
        TXCalendar(
            mode: .monthly,
            weeks: store.monthlyData,
            canMovePrevious: !store.previousMonthDisabled,
            canMoveNext: !store.nextMonthDisabled,
            config: .init(
                monthlyHorizontalPadding: 12,
                verticalPadding: 0,
                monthlyHeaderSpacing: 16,
                monthlyRowSpacing: 20,
                weekdayHeight: 24,
                dateStyle: .init(size: 44),
                dateCellBackground: { item in
                    guard let completedDate = completedDate(for: item) else { return nil }
                    
                    return AnyView(
                        dateImageBackground(
                            myImageUrl: completedDate.myImageUrl,
                            partnerImageUrl: completedDate.partnerImageUrl
                        )
                    )
                }
            ),
            onSelect: { item in
                if item.status == .completed {
                    store.send(.view(.calendarCellTapped(item)))
                }
            },
            onSwipe: { swipe in
                store.send(.view(.calendarSwiped(swipe)))
            }
        )
            .padding(.top, 24)
            .padding(.bottom, 32)
            .background(Color.Common.white, in: RoundedRectangle(cornerRadius: 16))
            .insideBorder(
                Color.Gray.gray500,
                shape: RoundedRectangle(cornerRadius: 16),
                lineWidth: 1
            )
            .background(alignment: .topLeading) {
                Image.Illustration.hug
                    .offset(x: 10, y: -48)
            }
            .overlay(alignment: .topTrailing) {
                Image.Illustration.plane
                    .offset(x: -7, y: -50)
            }
    }
    
    var statsInfoContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(store.statsSummaryInfo, id: \.title) { summary in
                HStack(spacing: 28) {
                    summaryTitle(for: summary.title)
                    summartyContent(content: summary.content, isCompletedCount: summary.isCompletedCount)
                        .layoutPriority(1)
                    
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .insideRectEdgeBorder(width: 1, edges: [.top, .bottom], color: Color.Gray.gray500)
    }
    
    func summaryTitle(for title: String) -> some View {
        Text(title)
            .typography(.c1_12r)
            .foregroundStyle(Color.Gray.gray400)
            .frame(width: 48, alignment: .leading)
    }
    
    func summartyContent(content: [String], isCompletedCount: Bool) -> some View {
        HStack(spacing: 0) {
            if isCompletedCount {
                Image.Icon.Symbol.check
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(Color.Gray.gray500)
                    .frame(width: 16, height: 16)
                    .padding(.trailing, 9)
            }
            
            Text(content[0])
                .typography(.b4_12b)
                .foregroundStyle(Color.Gray.gray500)
                .lineLimit(1)
            
            if isCompletedCount {
                Text("|")
                    .typography(.b4_12b)
                    .foregroundStyle(Color.Gray.gray200)
                    .padding(.horizontal, 8)
                
                Text(content[1])
                    .typography(.b4_12b)
                    .foregroundStyle(Color.Gray.gray500)
                    .lineLimit(1)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
    
    @ViewBuilder
    func dateImageBackground(
        myImageUrl: URL?,
        partnerImageUrl: URL?
    ) -> some View {
        let bothCompleted: Bool = myImageUrl != nil && partnerImageUrl != nil
        
        Group {
            if let myImageUrl,
               let partnerImageUrl {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.Dimmed.dimmed20)
                        .insideBorder(
                            Color.Gray.gray500,
                            shape: RoundedRectangle(cornerRadius: 7),
                            lineWidth: 1.2
                        )
                        .rotationEffect(.degrees(16))
                    
                    KFImage(partnerImageUrl)
                        .resizable()
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            } else if let myImageUrl {
                KFImage(myImageUrl)
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else if let partnerImageUrl {
                KFImage(partnerImageUrl)
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
        .frame(width: 36, height: 36)
        .insideBorder(
            bothCompleted ? Color.Common.white : Color.Gray.gray500,
            shape: RoundedRectangle(cornerRadius: 7),
            lineWidth: 1.2
        )
    }
}

// MARK: - Private Methods
private extension StatsDetailView {
    func completedDate(for item: TXCalendarDateItem) -> (myImageUrl: URL?, partnerImageUrl: URL?)? {
        guard item.status == .completed,
              let components = item.dateComponents,
              let dateKey = TXCalendarDate(components: components)?.formattedAPIDateString() else {
            return nil
        }
        
        guard let completedDate = store.completedDateByKey[dateKey] else { return nil }
        return (URL(string: completedDate.myImageUrl ?? ""), URL(string: completedDate.partnerImageUrl ?? ""))
    }
}

#Preview {
    StatsDetailView(
        store: Store(
            initialState: StatsDetailReducer.State(goalId: 1),
            reducer: { StatsDetailReducer() }
        )
    )
}
