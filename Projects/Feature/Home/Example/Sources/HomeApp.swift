import AVFoundation
import ComposableArchitecture
import CoreCaptureSession
import CoreCaptureSessionInterface
import DomainGoalInterface
import DomainNotificationInterface
import Foundation
import FeatureGoalDetail
import FeatureGoalDetailInterface
import FeatureHome
import FeatureHomeInterface
import FeatureMakeGoal
import FeatureMakeGoalInterface
import FeatureNotification
import FeatureNotificationInterface
import FeatureProofPhoto
import FeatureProofPhotoInterface
import FeatureSettings
import FeatureSettingsInterface
import FeatureStats
import FeatureStatsInterface
import SharedPerfTestingSupport
import SwiftUI

@main
struct HomeApp: App {
    init() {
        UITestMode.configureApplication()
    }

    var body: some Scene {
        WindowGroup {
            HomeCoordinatorView(
                store: Store(
                    initialState: HomeCoordinator.State(),
                    reducer: {
                        HomeCoordinator(
                            goalDetailReducer: GoalDetailReducer(
                                proofPhotoReducer: ProofPhotoReducer()
                            ),
                            statsDetailReducer: StatsDetailReducer(),
                            proofPhotoReducer: ProofPhotoReducer(),
                            makeGoalReducer: MakeGoalReducer(),
                            editGoalListReducer: EditGoalListReducer(),
                            settingsReducer: SettingsReducer(),
                            notificationReducer: NotificationReducer()
                        )
                    },
                    withDependencies: {
                        $0.goalClient = HomeApp.goalClient(for: UITestMode.seedName)
                        $0.notificationClient = .previewValue
                        $0.captureSessionClient = UITestMode.isEnabled ? .perfMock : .liveValue
                        $0.proofPhotoFactory = .liveValue
                        $0.goalDetailFactory = .liveValue
                        $0.statsDetailFactory = .liveValue
                        $0.makeGoalFactory = .liveValue
                        $0.settingsFactory = .liveValue
                        $0.notificationFactory = .liveValue
                    }
                )
            )
            .perfRoot("home")
            .perfReadyMarker("home")
        }
    }
}

private extension HomeApp {
    static func goalClient(for seed: String) -> GoalClient {
        guard UITestMode.isEnabled else { return .previewValue }
        switch seed {
        case "scroll-50":
            return perfGoalClient(count: 50)
        case "home-heavy":
            // First authoritative rendering driver dataset. 200 cells is
            // large enough to force multiple scroll passes and exercise
            // LazyVStack materialization without making the recording window
            // unbounded.
            return perfGoalClient(count: 200)
        default:
            return .previewValue
        }
    }

    static func perfGoalClient(count: Int) -> GoalClient {
        var client = GoalClient.previewValue
        client.fetchGoals = { _ in
            GoalList(
                hasEverRegisteredGoal: true,
                goals: (1...count).map(perfScrollGoal(index:))
            )
        }
        return client
    }

    static func perfScrollGoal(index: Int) -> Goal {
        let id = Int64(index)
        let icon: String = index.isMultiple(of: 2) ? "ICON_EXERCISE" : "ICON_BOOK"
        let myVerification = Goal.Verification(
            photologId: id * 10 + 1,
            isCompleted: index.isMultiple(of: 3),
            imageURL: nil,
            emoji: nil
        )
        let yourVerification = Goal.Verification(
            photologId: id * 10 + 2,
            isCompleted: index.isMultiple(of: 4),
            imageURL: nil,
            emoji: nil
        )
        return Goal(
            id: id,
            goalIcon: icon,
            title: "Perf scroll item #\(index)",
            myVerification: myVerification,
            yourVerification: yourVerification,
            repeatCycle: .daily,
            repeatCount: 1,
            startDate: "2026-02-01",
            endDate: nil
        )
    }
}

private extension CaptureSessionClient {
    static let perfMock = Self(
        fetchIsAuthorized: { true },
        setUpCaptureSession: { _ in AVCaptureSession() },
        stopRunning: {},
        capturePhoto: { Data() },
        switchCamera: { _ in },
        switchFlash: { _ in }
    )
}
