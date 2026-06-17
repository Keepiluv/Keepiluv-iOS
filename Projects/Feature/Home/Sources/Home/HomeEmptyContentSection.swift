//
//  HomeEmptyContentSection.swift
//  FeatureHome
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import SharedDesignSystem

/// `hadFirstGoal`을 읽는 빈 상태 영역입니다.
/// `goalEmptyView`의 center anchor를 기기 화면 기준 y축 중앙에 배치합니다.
struct HomeEmptyContentSection: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let frame = geo.frame(in: .global)
                let deviceHeight = UIScreen.main.bounds.height
                let deviceCenterYInSection = max(0, deviceHeight / 2 - frame.minY)

                ScrollView {
                    goalEmptyView
                        .frame(width: geo.size.width)
                        .position(x: geo.size.width / 2, y: deviceCenterYInSection)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    store.send(.view(.refreshPulled))
                }
                .overlay(alignment: .bottomTrailing) {
                    if store.hadFirstGoal == false {
                        emptyArrow
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    var goalEmptyView: some View {
        Group {
            if store.hadFirstGoal == true {
                VStack(spacing: 8) {
                    Image.Illustration.scare
                        .resizable()
                        .frame(width: 164, height: 164)

                    Text("이 날은 목표가 없어요!")
                        .typography(.t2_16b)
                        .foregroundStyle(Color.Gray.gray400)
                }
            } else if store.hadFirstGoal == false {
                VStack(spacing: 0) {
                    Image.Illustration.emptyPoke
                        .frame(height: 116)

                    Text("첫 목표를 세워볼까요?")
                        .typography(.t2_16b)
                        .foregroundStyle(Color.Gray.gray400)
                        .padding(.top, 16)

                    Text("+ 버튼을 눌러 목표를 추가해보세요")
                        .typography(.c1_12r)
                        .foregroundStyle(Color.Gray.gray300)
                        .padding(.top, 4)
                }
            }
        }
    }

    var emptyArrow: some View {
        Image.Illustration.arrow
            .padding(.bottom, 71 + TXTabBarLayout.height)
            .padding(.trailing, 86)
            .ignoresSafeArea()
    }
}
