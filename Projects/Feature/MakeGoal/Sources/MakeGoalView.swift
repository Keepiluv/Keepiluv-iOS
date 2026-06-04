//
//  MakeGoalView.swift
//  FeatureHomeInterface
//
//  Created by 정지훈 on 2/1/26.
//

import SwiftUI

import ComposableArchitecture
import FeatureMakeGoalInterface
import SharedDesignSystem

public struct MakeGoalView: View {
    
    @Bindable public var store: StoreOf<MakeGoalReducer>
    @FocusState private var isGoalTitleTextFieldFocused: Bool

    public init(store: StoreOf<MakeGoalReducer>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            navigationBar
                .padding(.horizontal, -20)

            ScrollView {
                VStack(spacing: 0) {
                    emojiCircle
                        .padding(.top, 52)
                    goalTitleField
                        .padding(.top, 44)
                    scheduleSection
                        .padding(.top, 44)
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)

            completeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 20)
        .ignoresSafeArea(.keyboard)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { store.send(.view(.onAppear)) }
        .onDisappear { store.send(.view(.onDisappear)) }
        .onTapGesture { store.send(.view(.dismissKeyboard)) }
        .onChange(of: isGoalTitleTextFieldFocused) { _, newValue in
            guard store.isGoalTitleFocused != newValue else { return }
            store.send(.view(.goalTitleFocusChanged(newValue)))
        }
        .onChange(of: store.isGoalTitleFocused) { _, newValue in
            guard isGoalTitleTextFieldFocused != newValue else { return }
            isGoalTitleTextFieldFocused = newValue
        }
        .txBottomSheet(
            isPresented: $store.isCalendarSheetPresented
        ) {
            TXCalendarBottomSheet(
                selectedDate: $store.calendarSheetDate,
                completeButtonText: "완료",
                onComplete: { store.send(.view(.monthCalendarConfirmTapped)) },
                isDateEnabled: store.isCalendarDateEnabled
            )
        }
        .txBottomSheet(
            isPresented: $store.isPeriodSheetPresented
        ) {
            periodSheet
        }
        .txModal(
            item: $store.modal,
            onAction: { action in
                if case let .confirmWithIndex(index) = action {
                    store.send(.view(.modalConfirmTapped(index)))
                }
            }
        )
        .txToast(item: $store.toast, customPadding: 70)
        .txLoading(isPresented: store.isLoading && store.submitMessage == nil)
        .txLoading(item: store.submitMessage)
    }
}

// MARK: - SubViews
private extension MakeGoalView {
    var navigationBar: some View {
        TXNavigationBar(
            style: .subTitle(
                title: store.mode.title,
                type: .back
            ), onAction: { _ in
                store.send(.view(.navigationBackButtonTapped))
            }
        )
    }
    
    var emojiCircle: some View {
        store.goalData.icon.thinImage
            .resizable()
            .frame(width: 64, height: 64)
            .padding(22)
            .background(Color.Gray.gray50, in: .circle)
            .insideBorder(
                Color.Gray.gray500,
                shape: .circle,
                lineWidth: LineWidth.m
            )
            .onTapGesture { store.send(.view(.emojiButtonTapped)) }
            .overlay(alignment: .bottomTrailing) {
                TXButton(
                    shape: .circle(
                        style: .basic(icon: Image.Icon.Symbol.turn),
                        size: .custom(
                            frameSize: .init(width: 28, height: 28),
                            iconSize: .init(width: 16, height: 16)
                        ),
                        state: .custom(
                            foregroundColor: Color.Gray.gray500,
                            backgroundColor: Color.Common.white
                        )
                    ),
                    onTap: { store.send(.view(.emojiButtonTapped)) }
                )
                .insideBorder(
                    Color.Gray.gray500,
                    shape: .circle,
                    lineWidth: LineWidth.m
                )
            }
    }
    
    var goalTitleField: some View {
        TXTextField(
            text: $store.goalData.title,
            placeholderText: "목표를 입력해 보세요",
            isFocused: $isGoalTitleTextFieldFocused,
            submitLabel: .done,
            subText: .init(text: "목표 이름 2-14자", state: validationState)
        )
    }
    
    var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            periodSection
            divider
            startDateRow
            divider
            endDateToggleRow
            
            if store.goalData.isEndDateOn {
                divider
                endDateRow
            }
        }
        .padding(.horizontal, 16)
        .insideBorder(
            Color.Gray.gray500,
            shape: RoundedRectangle(cornerRadius: 12),
            lineWidth: LineWidth.m
        )
    }
    
    var periodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitleText("반복 주기")
            
            HStack(spacing: 8) {
                TXTab(
                    style: .button(PeriodItem.allCases),
                    selectedItem: selectedPeriodItem,
                    onSelect: { store.send(.view(.periodTabSelected($0))) }
                )
                
                Spacer()
                
                if store.showPeriodCount {
                    dropDownButton { store.send(.view(.periodSelected)) }
                }
            }
        }
        .padding(.vertical, 16)
    }
    
    var startDateRow: some View {
        HStack(spacing: 8) {
            sectionTitleText("시작일")
            
            Spacer()
            
            dropDownButton { store.send(.view(.startDateTapped)) }
        }
        .frame(height: 32)
        .padding(.vertical, 16)
    }
    
    var endDateToggleRow: some View {
        HStack(spacing: 0) {
            sectionTitleText("종료일 설정")
            
            Spacer()
            
            TXToggleSwitch(isOn: $store.goalData.isEndDateOn)
        }
        .frame(height: 32)
        .padding(.vertical, 16)
    }
    
    var endDateRow: some View {
        HStack(spacing: 8) {
            sectionTitleText("종료일")
            
            Spacer()
            
            dropDownButton { store.send(.view(.endDateTapped)) }
        }
        .padding(.vertical, 21.5)
    }
    
    var completeButton: some View {
        TXButton(
            shape: .rect(
                style: .basic(text: "완료"),
                size: .l,
                state: store.completeButtonDisabled ? .disabled : .standard
            )
        ) { store.send(.view(.completeButtonTapped)) }
    }
    
    var divider: some View {
        Color.Gray.gray500
            .frame(height: 1)
            .padding(.horizontal, -16)
            .padding(.vertical, -1)
    }
    
    func dropDownButton(_ action: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Text(store.startDateText)
                .typography(.b2_14r)
                .foregroundStyle(Color.Gray.gray500)
            Image.Icon.Symbol.arrow2Down
        }
        .onTapGesture {
            action()
        }
    }
    
    func sectionTitleText(_ text: String) -> some View {
        Text(text)
            .typography(.b1_14b)
            .foregroundStyle(Color.Gray.gray500)
    }
    
    func valueText(_ text: String) -> some View {
        Text(text)
            .typography(.b2_14r)
            .foregroundStyle(Color.Gray.gray500)
    }
    
    var periodSheet: some View {
        VStack(spacing: 0) {
            periodTabButtons
            periodCountContent
                .padding(.top, 36)
            
            TXButton(
                shape: .rect(style: .basic(text: "완료"), size: .l, state: .standard),
                onTap: { store.send(.view(.periodSheetCompleteTapped)) }
            )
            .padding(.top, 32)
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }
    
    var periodTabButtons: some View {
        HStack(spacing: 8) {
            TXButton(
                shape: .rect(
                    style: .basic(text: store.weeklyPeriodText),
                    size: .s,
                    state: store.goalData.repeatCycle == .weekly ? .standard : .line
                ),
                onTap: { store.send(.view(.periodSheetWeeklyTapped)) }
            )
            
            TXButton(
                shape: .rect(
                    style: .basic(text: store.monthlyPeriodText),
                    size: .s,
                    state: store.goalData.repeatCycle == .monthly ? .standard : .line
                ),
                onTap: { store.send(.view(.periodSheetMonthlyTapped)) }
            )
        }
    }
    
    var periodCountContent: some View {
        HStack(spacing: 16) {
            TXButton(
                shape: .circle(
                    style: .basic(icon: .Icon.Symbol.minus),
                    size: .custom(
                        frameSize: .init(width: 36, height: 36),
                        iconSize: .init(width: 28, height: 28)
                    ),
                    state: store.isMinusEnable ? .standard : .disabled
                ),
                onTap: { store.send(.view(.periodSheetMinusTapped)) }
            )
            .disabled(!store.isMinusEnable)
            
            sheetPeriodCount
            
            TXButton(
                shape: .circle(
                    style: .basic(icon: .Icon.Symbol.plus),
                    size: .custom(
                        frameSize: .init(width: 36, height: 36),
                        iconSize: .init(width: 28, height: 28)
                    ),
                    state: store.isPlusEnable ? .standard : .disabled
                ),
                onTap: { store.send(.view(.periodSheetPlusTapped)) }
            )
            .disabled(!store.isPlusEnable)
        }
    }
    
    var sheetPeriodCount: some View {
        HStack(spacing: 8) {
            Text("\(store.periodCount)")
                .typography(.h2_24r)
                .foregroundStyle(Color.Gray.gray500)
                .frame(width: 33)
                .padding(.leading, 22)
            
            Text("번")
                .typography(.t2_16b)
                .foregroundStyle(Color.Gray.gray300)
                .padding(.trailing, 17)
        }
        .padding(.vertical, 12)
        .frame(width: 96)
        .insideBorder(
            Color.Gray.gray300,
            shape: RoundedRectangle(cornerRadius: 12),
            lineWidth: 1.2
        )
    }
}

// MARK: - Private Methods
private extension MakeGoalView {
    var validationState: TXTextField.SubTextConfiguration.State {
        if store.goalData.title.isEmpty {
            return .empty
        }
        return store.isInvalidTitle ? .valid : .invalid
    }
    
    var selectedPeriodItem: PeriodItem {
        PeriodItem(repeatCycle: store.goalData.repeatCycle)
    }
}
