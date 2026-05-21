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
                isPresented: $store.isAddGoalPresented,
                showDragIndicator: true,
                sheetContent: {
                    AddGoalListView { category in
                        store.send(.addGoalButtonTapped(category))
                    }
                }
            )
            .txBottomSheet(
                isPresented: $store.isCalendarSheetPresented,
                sheetContent: {
                    TXCalendarBottomSheet(
                        selectedDate: $store.calendarSheetDate,
                        completeButtonText: "완료",
                        onComplete: {
                            store.send(.monthCalendarConfirmTapped)
                        }
                    )
                }
            )
            .txModal(
                item: $store.modal,
                onAction: { action in
                    if action == .confirm {
                        store.send(.modalConfirmTapped)
                    }
                }
            )
            .transaction { transaction in
                transaction.disablesAnimations = false
            }
            .fullScreenCover(
                isPresented: $store.isProofPhotoPresented,
                onDismiss: { store.send(.proofPhotoDismissed) },
            ) {
                if let proofPhotoStore = store.scope(state: \.proofPhoto, action: \.proofPhoto) {
                    proofPhotoFactory.makeView(proofPhotoStore)
                }
            }
            .cameraPermissionAlert(
                isPresented: $store.isCameraPermissionAlertPresented,
                onDismiss: { store.send(.cameraPermissionAlertDismissed) }
            )
    }
}
