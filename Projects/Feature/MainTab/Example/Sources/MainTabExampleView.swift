//
//  MainTabExampleView.swift
//  FeatureMainTabExample
//
//  Created by 정지훈 on 1/28/26.
//

import AVFoundation
import SwiftUI

import ComposableArchitecture
import Feature
import CoreCaptureSession
import CoreCaptureSessionInterface
import DomainGoalInterface
import FeatureMakeGoal
import FeatureMakeGoalInterface
import SharedPerfTestingSupport

struct MainTabExampleView: View {
    var body: some View {
        MainTabView(
            store: Store(
                initialState: MainTabReducer.State(),
                reducer: {
                    MainTabReducer()
                }, withDependencies: {
                    $0.goalClient = .previewValue
                    $0.captureSessionClient = UITestMode.isEnabled ? .perfMock : .liveValue
                    $0.proofPhotoFactory = .liveValue
                    $0.goalDetailFactory = .liveValue
                    $0.makeGoalFactory = .liveValue
                }
            )
        )
    }
}

#Preview {
    MainTabExampleView()
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
