//
//  SettingsApp.swift
//  FeatureSettingsExample
//
//  Created by Jiyong on 02/05/26.
//

import ComposableArchitecture
import DomainAuthInterface
import DomainOnboardingInterface
import FeatureSettings
import FeatureSettingsInterface
import SharedDesignSystem
import SharedPerfTestingSupport
import SwiftUI

@main
struct SettingsApp: App {
    init() {
        UITestMode.configureApplication()
    }

    var body: some Scene {
        WindowGroup {
            SettingsView(
                store: Store(
                    initialState: SettingsReducer.State(
                        nickname: "김민정",
                        coupleCode: "JF2342S"
                    ),
                    reducer: {
                        SettingsReducer()
                    },
                    withDependencies: {
                        $0.authClient = .previewValue
                        $0.onboardingClient = .previewValue
                    }
                )
            )
            .perfRoot("settings")
            .perfReadyMarker("settings")
        }
    }
}
