//
//  GoalDetailExampleView.swift
//  FeatureGoalDetailExample
//
//  Created by 정지훈 on 1/23/26.
//

import AVFoundation
import SwiftUI

import ComposableArchitecture
import CoreCaptureSession
import CoreCaptureSessionInterface
import DomainGoalInterface
import DomainPhotoLogInterface
import FeatureGoalDetail
import FeatureGoalDetailInterface
import FeatureProofPhoto
import FeatureProofPhotoInterface
import SharedPerfTestingSupport
import SharedDesignSystem

struct GoalDetailExampleView: View {
    var body: some View {
        GoalDetailView(
            store: Store(
                initialState: GoalDetailReducer.State(
                    // Branch by launch scenario.
                    //
                    // - Probe / rendering scenarios target `ReactionBarView`,
                    //   which is gated by `isShowReactionBar = !isFrontMyCard
                    //   && isCompleted`. They require `.you`.
                    // - Default-mode tests (Smoke / Navigation / ColdLaunch)
                    //   target the primary-cta button (`feature.goal-detail
                    //   .primary-cta`), which is only present when
                    //   `isFrontMyCard` (i.e. `.mySelf`). Forcing `.you` for
                    //   them would hide the button and break the navigation
                    //   test.
                    currentUser: Self.initialCurrentUser,
                    id: 1,
                    verificationDate: "2026-02-07"
                ),
                reducer: {
                    GoalDetailReducer(
                        proofPhotoReducer: ProofPhotoReducer()
                    )
                }, withDependencies: {
                    $0.captureSessionClient = UITestMode.isEnabled ? .perfMock : .liveValue
                    $0.proofPhotoFactory = .liveValue
                    $0.goalClient = .previewValue
                    // Local no-op mock for the reaction update path. Without
                    // it, `reactionEmojiTapped` would hit a real network
                    // client and either crash (testValue) or fan out to the
                    // server. Rendering scenarios must stay local.
                    $0.photoLogClient = .perfMock
                }
            )
        )
    }
}

private extension GoalDetailExampleView {
    /// Pick `.you` only when a Pass 3 PERF scenario is active so the
    /// reaction bar is reachable. Otherwise default to `.mySelf` so the
    /// primary-cta button is visible — required by the existing
    /// `GoalDetailExampleNavigationTests`.
    static var initialCurrentUser: GoalDetail.Owner {
        if UITestMode.isProbeScenario || UITestMode.isRenderingScenario {
            return .you
        }
        return .mySelf
    }
}

#Preview {
    GoalDetailExampleView()
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

private extension PhotoLogClient {
    /// Local no-op mock for Pass 3 rendering scenarios. Each closure returns
    /// an empty success response without touching the network. Only
    /// `updateReaction` is exercised by the reaction rapid-fire scenario;
    /// the others are stubs to satisfy the struct's required initializer.
    static let perfMock = Self(
        fetchUploadURL: { _ in
            PhotoLogUploadURLResponseDTO(uploadUrl: "", fileName: "")
        },
        uploadImageData: { _, _ in },
        createPhotoLog: { _ in
            PhotoLogCreateResponseDTO(
                photologId: 0,
                goalId: 0,
                imageUrl: "",
                comment: "",
                verificationDate: ""
            )
        },
        updateReaction: { photologId, request in
            PhotoLogUpdateReactionResponseDTO(
                photologId: photologId,
                reaction: request.reaction
            )
        },
        updatePhotoLog: { _, _ in },
        deletePhotoLog: { _ in }
    )
}
