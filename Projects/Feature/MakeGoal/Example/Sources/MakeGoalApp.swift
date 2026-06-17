import ComposableArchitecture
import DomainGoalInterface
import FeatureMakeGoal
import FeatureMakeGoalInterface
import SharedPerfTestingSupport
import SwiftUI

@main
struct MakeGoalApp: App {
    init() {
        UITestMode.configureApplication()
    }

    var body: some Scene {
        WindowGroup {
            MakeGoalView(
                store: Store(
                    initialState: MakeGoalReducer.State(mode: .add(.book)),
                    reducer: { MakeGoalReducer() },
                    withDependencies: {
                        $0.goalClient = .previewValue
                    }
                )
            )
            .perfRoot("make-goal")
            .perfReadyMarker("make-goal")
        }
    }
}
