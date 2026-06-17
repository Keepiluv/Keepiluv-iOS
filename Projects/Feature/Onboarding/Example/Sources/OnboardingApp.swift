//
//  OnboardingApp.swift
//  FeatureOnboardingExample
//
//  Created by Jihun on 12/29/25.
//

import ComposableArchitecture
import DomainNotificationInterface
import DomainOnboardingInterface
import FeatureOnboarding
import SharedPerfTestingSupport
import SwiftUI

@main
struct OnboardingApp: App {
    let store: StoreOf<OnboardingCoordinator>

    init() {
        UITestMode.configureApplication()
        self.store = Store(
            initialState: OnboardingCoordinator.State(
                myInviteCode: "KDJ34923"
            ),
            reducer: { OnboardingCoordinator() },
            withDependencies: {
                $0.onboardingClient = .previewValue
                $0.notificationClient = .previewValue
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            OnboardingCoordinatorView(store: store)
                .perfRoot("onboarding")
                .perfReadyMarker("onboarding")
                .onOpenURL { url in
                    if let code = parseInviteCode(from: url) {
                        store.send(.deepLinkReceived(code: code))
                    }
                }
        }
    }
}

// MARK: - Deep Link Parsing

private func parseInviteCode(from url: URL) -> String? {
    guard url.path == "/invite" || url.path == "invite",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
          !code.isEmpty else {
        return nil
    }
    return code
}
