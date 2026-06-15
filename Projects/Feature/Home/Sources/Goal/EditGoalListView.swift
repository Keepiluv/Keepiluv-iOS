//
//  EditGoalListView.swift
//  FeatureHome
//
//  Created by 정지훈 on 2/4/26.
//

import SwiftUI

import ComposableArchitecture
import FeatureCommonInterface
import FeatureHomeInterface
import SharedDesignSystem

struct EditGoalListView: View {
    
    @Bindable var store: StoreOf<EditGoalListReducer>
    
    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            weekCalendar
                .padding(.top, 4)

            if store.isFetchFailed {
                DataRetryView {
                    store.send(.view(.dataRetryTapped))
                }
            } else if let cards = store.cards {
                if cards.isEmpty {
                    emptyContent
                } else {
                    cardScrollView
                        .padding(.bottom, 1)
                }
            } else {
                Spacer()
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            store.send(.view(.onAppear))
        }
        .onDisappear {
            store.send(.view(.onDisappear))
        }
        .onTapGesture {
            guard store.selectedCardMenu != nil else { return }
            store.send(.view(.backgroundTapped))
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .txModal(
            item: $store.modal,
            onAction: { action in
                if action == .confirm {
                    store.send(.view(.modalConfirmTapped))
                }
            }
        )
        .txToast(item: $store.toast, onButtonTap: {
            store.send(.view(.toastButtonTapped))
        })
        .txLoading(isPresented: store.isLoading)
    }
}

private extension EditGoalListView {
    var navigationBar: some View {
        TXNavigationBar(style: .subTitle(title: "편집", type: .back)) { _ in
            store.send(.view(.navigationBackButtonTapped))
        }
    }
    
    var weekCalendar: some View {
        TXCalendar(
            mode: .weekly,
            currentDate: $store.calendarDate,
            weeks: store.calendarWeeks,
            onSelect: { item in
                store.send(.view(.calendarDateSelected(item)))
            },
            onSwipe: { swipe in
                store.send(.view(.weekCalendarSwipe(swipe)))
            }
        )
        .frame(maxWidth: .infinity, maxHeight: 76)
    }
    
    var cardScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(store.cards ?? []) { card in
                    GoalEditCardView(
                        item: .init(
                            id: card.id,
                            goalName: card.goalName,
                            iconImage: card.iconImage,
                            repeatCycle: card.repeatCycle,
                            startDate: card.startDate,
                            endDate: card.endDate
                        ),
                        onMenuTap: {
                            store.send(.view(.cardMenuButtonTapped(card)))
                        }
                    )
                    .overlay(alignment: .topTrailing) {
                        if store.selectedCardMenu == card {
                            dropdown
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    var dropdown: some View {
        TXDropdown(items: GoalDropList.allCases) { action in
            store.send(.view(.cardMenuItemSelected(action)))
        }
        .offset(x: -16, y: 48)
    }
    
    var emptyContent: some View {
        VStack(spacing: 16) {
            Image.Illustration.emptyPoke
            
            Text("아직 목표가 없어요!")
                .typography(.t2_16b)
                .foregroundStyle(Color.Gray.gray400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#Preview {
    EditGoalListView(
        store: Store(
            initialState: EditGoalListReducer.State(
                calendarDate: .init(year: 2026, month: 02, day: 15)
            ),
            reducer: {
                EditGoalListReducer()
            }
        )
    )
}
