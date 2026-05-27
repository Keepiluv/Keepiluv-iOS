//
//  AuthApp.swift
//
//
//  Created by Jiyong
//

import ComposableArchitecture
import FeatureAuth
import SharedPerfTestingSupport
import SwiftUI

@main
struct AuthApp: App {
    init() {
        UITestMode.configureApplication()
    }

    var body: some Scene {
        WindowGroup {
            AuthView(
                store: Store(
                    initialState: AuthReducer.State(),
                    reducer: { AuthReducer() }
                )
            )
            .perfRoot("auth")
            .perfReadyMarker("auth")
        }
    }
}
