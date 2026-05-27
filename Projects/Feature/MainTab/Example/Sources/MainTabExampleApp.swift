//
//  MainTabExampleApp.swift
//  FeatureMainTab
//
//  Created by 정지훈 on 1/27/26.
//

import SwiftUI
import SharedPerfTestingSupport

@main
struct MainTabExampleApp: App {
    init() {
        UITestMode.configureApplication()
    }

    var body: some Scene {
        WindowGroup {
            MainTabExampleView()
                .perfRoot("main-tab")
                .perfReadyMarker("main-tab")
        }
    }
}
