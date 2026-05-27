//
//  StatsCoordinatorView.swift
//  FeatureStats
//
//  Created by 정지훈 on 2/19/26.
//

import SwiftUI

import ComposableArchitecture
import FeatureGoalDetailInterface
import FeatureMakeGoalInterface
import FeatureStatsInterface
import SharedPerfTestingSupport

/// Stats Feature의 루트 화면을 렌더링하는 Coordinator View입니다.
public struct StatsCoordinatorView: View {
    @Dependency(\.goalDetailFactory) var goalDetailFactory
    @Dependency(\.makeGoalFactory) var makeGoalFactory
    @Bindable var store: StoreOf<StatsCoordinator>
    
    /// StatsCoordinator Store를 주입받아 뷰를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let view = StatsCoordinatorView(
    ///     store: Store(
    ///         initialState: StatsCoordinator.State()
    ///     ) {
    ///         StatsCoordinator(
    ///             statsReducer: .init(),
    ///             statsDetailReducer: .init()
    ///         )
    ///     }
    /// )
    /// ```
    public init(store: StoreOf<StatsCoordinator>) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack(path: $store.routes) {
            StatsView(store: store.scope(state: \.stats, action: \.stats))
                .navigationDestination(for: StatsRoute.self) { route in
                    switch route {
                    case .statsDetail:
                        if let statsDetailStore = store.scope(state: \.statsDetail, action: \.statsDetail) {
                            StatsDetailView(store: statsDetailStore)
                                .toolbar(.hidden, for: .tabBar)
                                .perfReadyMarker("stats-to-stats-detail")
                        }

                    case .goalDetail:
                        if let goalDetailStore = store.scope(state: \.goalDetail, action: \.goalDetail) {
                            goalDetailFactory.makeView(goalDetailStore)
                                .toolbar(.hidden, for: .tabBar)
                        }

                    case .makeGoal:
                        if let makeGoalStore = store.scope(state: \.makeGoal, action: \.makeGoal) {
                            makeGoalFactory.makeView(makeGoalStore)
                                .toolbar(.hidden, for: .tabBar)
                        }
                    }
                }
        }
    }
}

//#Preview {
//    StatsCoordinatorView(
//        store: Store(
//            initialState: StatsCoordinator.State(),
//            reducer: {
//                StatsCoordinator(
//                    statsReducer: .init(),
//                    statsDetailReducer: .init(),
//                    goalDetailReducer: <#T##GoalDetailReducer#>
//                )
//            }, withDependencies: {
//                $0.statsClient = .testValue
//            }
//        )
//    )
//}
