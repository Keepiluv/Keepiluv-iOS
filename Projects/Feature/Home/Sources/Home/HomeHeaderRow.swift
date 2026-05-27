//
//  HomeHeaderRow.swift
//  FeatureHome
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import SharedDesignSystem

/// `goalSectionTitle` 재계산이 콘텐츠 전체나 카드 리스트 대신 작은 Text row만
/// invalidate하도록 분리한 영역입니다.
struct HomeHeaderRow: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        HStack(spacing: 0) {
            Text(store.goalSectionTitle)
                .typography(.b1_14b)

            Spacer()

            Button {
                store.send(.editButtonTapped)
            } label: {
                Text("편집")
                    .typography(.b1_14b)
                    .foregroundStyle(Color.Gray.gray500)
            }
        }
        .frame(height: 24)
    }
}
