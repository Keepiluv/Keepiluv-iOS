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
import SharedDesignSystem
import SharedPerfTestingSupport

struct MainTabExampleView: View {
    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-UITEST_DESIGN_SYSTEM_BOTTOM_SHEET_SCENARIO") {
            DesignSystemBottomSheetScenarioView()
        } else {
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

private struct DesignSystemBottomSheetScenarioView: View {
    @State private var selectedTab: TXTabItem = .home
    @State private var selectedDate = TXCalendarDate(year: 2026, month: 5, day: 28)
    @State private var isBottomSheetPresented = false
    @State private var completedCount = 0
    @State private var selfRunStep = 0
    @State private var hasStartedSelfRun = false

    var body: some View {
        TXTabBarContainer(selectedItem: $selectedTab) {
            scenarioContent(title: "홈")
                .tag(TXTabItem.home)

            scenarioContent(title: "통계")
                .tag(TXTabItem.statistics)
        }
        .txBottomSheet(
            isPresented: $isBottomSheetPresented,
            showDragIndicator: true
        ) {
            TXCalendarBottomSheet(
                selectedDate: $selectedDate,
                completeButtonText: "완료",
                onComplete: {
                    completedCount += 1
                    isBottomSheetPresented = false
                }
            )
            .overlay(alignment: .topLeading) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier(
                        "example.bottom-sheet.calendar-month.\(selectedDate.formattedYearDashMonth)"
                    )
            }
        }
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("example.bottom-sheet.completed-count.\(completedCount)")
        }
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("example.bottom-sheet.self-run-step.\(selfRunStep)")
        }
        .task {
            await runCalendarBottomSheetSelfRunIfNeeded()
        }
    }

    private func scenarioContent(title: String) -> some View {
        VStack(spacing: Spacing.spacing6) {
            Text(title)
                .typography(.t1_18eb)
                .foregroundStyle(Color.Gray.gray500)

            Button("캘린더 바텀시트 열기") {
                isBottomSheetPresented = true
            }
            .accessibilityIdentifier("example.bottom-sheet.present-button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .overlay(alignment: .topLeading) {
            Button {
                triggerQuickRepresentRace()
            } label: {
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("example.bottom-sheet.quick-represent-button")
        }
    }

    private func triggerQuickRepresentRace() {
        isBottomSheetPresented = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            isBottomSheetPresented = false
            try? await Task.sleep(for: .milliseconds(50))
            isBottomSheetPresented = true
        }
    }

    @MainActor
    private func runCalendarBottomSheetSelfRunIfNeeded() async {
        guard UITestMode.isSwiftUISelfRunCalendarBottomSheet, !hasStartedSelfRun else { return }
        hasStartedSelfRun = true

        try? await Task.sleep(for: .milliseconds(900))
        for iteration in 1...4 {
            selfRunStep = (iteration * 10) + 1
            isBottomSheetPresented = true
            try? await Task.sleep(for: .milliseconds(650))

            selfRunStep = (iteration * 10) + 2
            selectedDate.goToNextMonth()
            try? await Task.sleep(for: .milliseconds(250))

            selfRunStep = (iteration * 10) + 3
            isBottomSheetPresented = false
            try? await Task.sleep(for: .milliseconds(450))
        }

        selfRunStep = 999
    }
}
