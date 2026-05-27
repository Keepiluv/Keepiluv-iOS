//
//  HomeEmptyContentSection.swift
//  FeatureHome
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import SharedDesignSystem

/// `hadFirstGoal`을 읽는 빈 상태 영역입니다.
/// `emptyScrollHeight`는 로컬 `@State`로 관리해 다른 콘텐츠 section 재렌더링에 의해
/// 초기화되지 않게 합니다.
struct HomeEmptyContentSection: View {
    let store: StoreOf<HomeReducer>

    @State private var emptyScrollHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HomeHeaderRow(store: store)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ScrollView {
                goalEmptyView
                    // 실제 가시 영역 기준으로 중앙 정렬되도록 탭바 높이만큼 차감
                    .frame(maxWidth: .infinity, minHeight: max(0, emptyScrollHeight - 58))
                    .padding(.bottom, 58)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                store.send(.fetchGoals)
            }
            .overlay(alignment: .bottomTrailing) {
                emptyArrow
            }
            .frame(maxHeight: .infinity)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { emptyScrollHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, newValue in
                            emptyScrollHeight = newValue
                        }
                }
            }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var emptyArrow: some View {
        Image.Illustration.arrow
            .padding(.bottom, 71 + 58)
            .padding(.trailing, 86)
            .ignoresSafeArea()
    }
}
