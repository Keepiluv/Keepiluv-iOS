//
//  HomePresentationLayer.swift
//  FeatureHome
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import FeatureProofPhotoInterface
import SharedDesignSystem

/// 모든 presentation modifier(bottom sheet, modal, fullScreenCover, alert)를 소유합니다.
/// Presentation binding read-set을 이 modifier body로 모아, presentation flag 변경이
/// `HomeContentSection`이나 `HomeNavigationBarSection`을 invalidate하지 않게 합니다.
struct HomePresentationLayer: ViewModifier {
    @Bindable var store: StoreOf<HomeReducer>
    @Dependency(\.proofPhotoFactory) var proofPhotoFactory

    func body(content: Content) -> some View {
        content
            .txBottomSheet(
                isPresented: $store.presentation.isAddGoalPresented,
                showDragIndicator: true,
                sheetContent: {
                    AddGoalListView { category in
                        store.send(.view(.addGoalButtonTapped(category)))
                    }
                }
            )
            .txBottomSheet(
                isPresented: $store.presentation.isCalendarSheetPresented,
                sheetContent: {
                    TXCalendarBottomSheet(
                        selectedDate: $store.data.calendarSheetDate,
                        completeButtonText: "완료",
                        onComplete: {
                            store.send(.view(.monthCalendarConfirmTapped))
                        }
                    )
                }
            )
            .txModal(
                item: $store.presentation.modal,
                onAction: { action in
                    if action == .confirm {
                        store.send(.view(.modalConfirmTapped))
                    }
                }
            )
            .transaction { transaction in
                transaction.disablesAnimations = false
            }
            .fullScreenCover(
                isPresented: $store.presentation.isProofPhotoPresented,
                onDismiss: { store.send(.view(.proofPhotoDismissed)) },
            ) {
                if let proofPhotoStore = store.scope(state: \.proofPhoto, action: \.proofPhoto) {
                    proofPhotoFactory.makeView(proofPhotoStore)
                }
            }
            .cameraPermissionAlert(
                isPresented: $store.presentation.isCameraPermissionAlertPresented,
                onDismiss: { store.send(.view(.cameraPermissionAlertDismissed)) }
            )
    }
}
