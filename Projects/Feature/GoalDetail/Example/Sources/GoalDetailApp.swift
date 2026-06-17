//
//  GoalDetailView.swift
//
//
//  Created by Jihun on 01/21/26.
//

import SwiftUI

import ComposableArchitecture
import CoreCaptureSession
import CoreCaptureSessionInterface
import SharedPerfTestingSupport

@main
struct GoalDetailApp: App {
    init() {
        UITestMode.configureApplication()
    }

    var body: some Scene {
        WindowGroup {
            GoalDetailExampleView()
                .perfRoot("goal-detail")
                .perfReadyMarker("goal-detail")
        }
    }
}
