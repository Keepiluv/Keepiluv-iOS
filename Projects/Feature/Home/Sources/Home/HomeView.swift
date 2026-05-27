//
//  HomeView.swift
//  FeatureHome
//
//  Created by 정지훈 on 1/26/26.
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import FeatureProofPhotoInterface
import SharedDesignSystem
import SharedPerfTestingSupport

/// 홈 화면을 렌더링하는 View입니다.
///
/// ## 사용 예시
/// ```swift
/// HomeView(
///     store: Store(
///         initialState: HomeReducer.State()
///     ) {
///         HomeReducer()
///     }
/// )
/// ```
///
/// ## Read-set split (Pass 3 Commit 3)
///
/// The view is decomposed into sibling sub-view structs so SwiftUI's
/// `@ObservableState` observation tracking can isolate which fields cause
/// which sub-view to re-render. Each sub-view's body only reads the fields
/// it actually uses, so a change to one field only invalidates the views
/// that observe it. Presentation modifiers (sheets / modal / fullScreenCover
/// / alert) move into `HomePresentationLayer`, a ViewModifier whose body
/// reads the presentation bindings — keeping that read-set off the parent
/// `HomeView.body`.
public struct HomeView: View {

    @Bindable public var store: StoreOf<HomeReducer>

    /// HomeView를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let view = HomeView(store: Store(initialState: HomeReducer.State()) { HomeReducer() })
    /// ```
    public init(store: StoreOf<HomeReducer>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // PERF probe harness — activated only for probe scenarios
            // (`-UITEST_PROBE_SCENARIO`). Reading store.toast / store.calendarDate
            // inside the harness adds an artificial read to the parent body;
            // this is acceptable because probe scenarios are not the
            // authoritative rendering metric.
            if UITestMode.isProbeScenario {
                HomePerfActionHarness(store: store)
                PerfRebuildProxyPing("home.view.rebuild.proxy")
            }
            HomeNavigationBarSection(store: store)
            HomeCalendarSection(store: store)
            // The branch reads `hasCards` / `isEmptyVisible` so it stays in
            // the parent body. Both are cheap derived booleans. Items /
            // headerRow read-set lives entirely inside the child sub-view.
            if store.hasCards {
                HomeContentSection(store: store)
            } else if store.isEmptyVisible {
                HomeEmptyContentSection(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(PerfToastPresentationHarness(toast: $store.toast))
        .modifier(PerfHomeCounterMarkersHarness())
        .modifier(HomePresentationLayer(store: store))
        .onAppear {
            store.send(.onAppear)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - HomeNavigationBarSection

/// Reads `mainTitle`, `calendarMonthTitle`, `isRefreshHidden`,
/// `hasUnreadNotification`. Isolated so changes to content / presentation
/// fields do not invalidate the nav bar.
private struct HomeNavigationBarSection: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        TXNavigationBar(
            style: .home(
                .init(
                    subTitle: store.calendarMonthTitle,
                    mainTitle: store.mainTitle,
                    isHiddenRefresh: store.isRefreshHidden,
                    isRemainedAlarm: store.hasUnreadNotification
                )
            ), onAction: { action in
                store.send(.navigationBarAction(action))
            }
        )
    }
}

// MARK: - HomeCalendarSection

/// Reads `$calendarDate` (binding) and `calendarWeeks`. Calendar-month
/// probe marker stays inside this sub-view so the value read does NOT
/// leak into the parent body.
private struct HomeCalendarSection: View {
    @Bindable var store: StoreOf<HomeReducer>

    var body: some View {
        let calendarView = TXCalendar(
            mode: .weekly,
            currentDate: $store.calendarDate,
            weeks: store.calendarWeeks,
            config: .init(
                dateStyle: .init(lastDateTextColor: Color.Gray.gray500)
            ),
            onSelect: { item in
                store.send(.calendarDateSelected(item))
            },
            onSwipe: { swipe in
                store.send(.weekCalendarSwipe(swipe))
            }
        )
        .frame(maxWidth: .infinity, maxHeight: 76)
        .perfControl(slug: "home", element: "calendar")

        if UITestMode.isProbeScenario {
            calendarView.perfStateMarker(
                slug: "home",
                key: "calendar-month",
                value: "\(store.calendarDate.year)-\(store.calendarDate.month)"
            )
        } else {
            calendarView
        }
    }
}

// MARK: - HomeContentSection

/// Reads `items`, `goalSectionTitle`. Owns the 50/200-cell `LazyVStack`
/// whose ForEach is the dominant rendering cost. Presentation flag
/// changes (toast / sheets / modal / alert) do NOT invalidate this view
/// because they live in `HomePresentationLayer`.
private struct HomeContentSection: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        ScrollView {
            Group {
                HomeHeaderRow(store: store)
                cardList
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 103)
        }
        .refreshable {
            store.send(.fetchGoals)
        }
    }

    var cardList: some View {
        LazyVStack(spacing: 16) {
            ForEach(store.items) { item in
                goalCard(for: item)
                    .perfCell(slug: "home", stableId: item.id)
            }
        }
        .padding(.top, 12)
        .perfFeed("home")
    }

    func goalCard(for item: HomeGoalItem) -> some View {
        GoalCardView(
            item: item.card,
            onHeaderTapped: { store.send(.headerTapped(item.card)) },
            onCheckButtonTapped: {
                store.send(.goalCheckButtonTapped(
                    id: item.id,
                    isChecked: item.card.myCard.isSelected
                ))
            },
            actionLeft: { store.send(.myCardTapped(item.card)) },
            actionRight: { store.send(.yourCardTapped(item.card)) }
        )
    }
}

// MARK: - HomeHeaderRow

/// Isolated so `goalSectionTitle` re-computation only invalidates this
/// small Text row, not the entire content section or the card list.
private struct HomeHeaderRow: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        HStack(spacing: 0) {
            Text(store.goalSectionTitle)
                .typography(.b1_14b)

            Spacer()

            Button {
                store.send(.editButtonTapped)
            } label: {
                Text("편집")
                    .typography(.b1_14b)
                    .foregroundStyle(Color.Gray.gray500)
            }
        }
        .frame(height: 24)
    }
}

// MARK: - HomeEmptyContentSection

/// Reads `hadFirstGoal`. Manages local `emptyScrollHeight` `@State` so it
/// doesn't get reset when content sections re-render.
private struct HomeEmptyContentSection: View {
    let store: StoreOf<HomeReducer>

    @State private var emptyScrollHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HomeHeaderRow(store: store)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ScrollView {
                goalEmptyView
                    // 실제 가시 영역 기준으로 중앙 정렬되도록 탭바 높이만큼 차감
                    .frame(maxWidth: .infinity, minHeight: max(0, emptyScrollHeight - 58))
                    .padding(.bottom, 58)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                store.send(.fetchGoals)
            }
            .overlay(alignment: .bottomTrailing) {
                emptyArrow
            }
            .frame(maxHeight: .infinity)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { emptyScrollHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, newValue in
                            emptyScrollHeight = newValue
                        }
                }
            }
        }
    }

    @ViewBuilder
    var goalEmptyView: some View {
        Group {
            if store.hadFirstGoal == true {
                VStack(spacing: 8) {
                    Image.Illustration.scare
                        .resizable()
                        .frame(width: 164, height: 164)

                    Text("이 날은 목표가 없어요!")
                        .typography(.t2_16b)
                        .foregroundStyle(Color.Gray.gray400)
                }
            } else if store.hadFirstGoal == false {
                VStack(spacing: 0) {
                    Image.Illustration.emptyPoke
                        .frame(height: 116)

                    Text("첫 목표를 세워볼까요?")
                        .typography(.t2_16b)
                        .foregroundStyle(Color.Gray.gray400)
                        .padding(.top, 16)

                    Text("+ 버튼을 눌러 목표를 추가해보세요")
                        .typography(.c1_12r)
                        .foregroundStyle(Color.Gray.gray300)
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var emptyArrow: some View {
        Image.Illustration.arrow
            .padding(.bottom, 71 + 58)
            .padding(.trailing, 86)
            .ignoresSafeArea()
    }
}

// MARK: - HomePresentationLayer

/// Owns ALL presentation modifiers (bottom sheets, modal, fullScreenCover,
/// alert) and their bindings to `$store.isAddGoalPresented`,
/// `$store.isCalendarSheetPresented`, `$store.calendarSheetDate`,
/// `$store.modal`, `$store.isProofPhotoPresented`, `$store.proofPhoto`
/// (scope), and `$store.isCameraPermissionAlertPresented`. SwiftUI's
/// `@ObservableState` tracking scopes those reads to this modifier's body,
/// so a presentation flag flip does not invalidate `HomeContentSection` or
/// `HomeNavigationBarSection`.
private struct HomePresentationLayer: ViewModifier {
    @Bindable var store: StoreOf<HomeReducer>
    @Dependency(\.proofPhotoFactory) var proofPhotoFactory

    func body(content: Content) -> some View {
        content
            .txBottomSheet(
                isPresented: $store.isAddGoalPresented,
                showDragIndicator: true,
                sheetContent: {
                    AddGoalListView { category in
                        store.send(.addGoalButtonTapped(category))
                    }
                }
            )
            .txBottomSheet(
                isPresented: $store.isCalendarSheetPresented,
                sheetContent: {
                    TXCalendarBottomSheet(
                        selectedDate: $store.calendarSheetDate,
                        completeButtonText: "완료",
                        onComplete: {
                            store.send(.monthCalendarConfirmTapped)
                        }
                    )
                }
            )
            .txModal(
                item: $store.modal,
                onAction: { action in
                    if action == .confirm {
                        store.send(.modalConfirmTapped)
                    }
                }
            )
            .transaction { transaction in
                transaction.disablesAnimations = false
            }
            .fullScreenCover(
                isPresented: $store.isProofPhotoPresented,
                onDismiss: { store.send(.proofPhotoDismissed) },
            ) {
                if let proofPhotoStore = store.scope(state: \.proofPhoto, action: \.proofPhoto) {
                    proofPhotoFactory.makeView(proofPhotoStore)
                }
            }
            .cameraPermissionAlert(
                isPresented: $store.isCameraPermissionAlertPresented,
                onDismiss: { store.send(.cameraPermissionAlertDismissed) }
            )
    }
}

// MARK: - HomePerfActionHarness

/// PERF-only controls used by Pass 3 **probe scenarios** (toast / calendar
/// month toggle). Extracted into its own sub-view so its reads on
/// `store.calendarDate` (for the month-toggle buttons) don't pollute the
/// parent `HomeView.body` read-set even when the probe scenario is active
/// (lower-order concern — the probe scenario is not the authoritative
/// rendering metric, but isolation is still good hygiene).
///
/// Production builds never enter this branch because
/// `UITestMode.isProbeScenario` requires the `-UITEST_PROBE_SCENARIO`
/// launch argument. Buttons use a 44x44 Text label so `XCUIElement.tap()`
/// can resolve a valid hit point.
///
/// **Known limitation**: this harness is the first child of HomeView's
/// VStack and shifts the production layout by ~44pt when the probe
/// scenario is active. `.overlay` placement (which would be
/// layout-neutral) produced non-deterministic `hit point {-1, -1}` for
/// some buttons on iOS 26.2 simulator. **The harness must NOT be mixed
/// into authoritative rendering scenarios** — rendering scenarios launch
/// via `-UITEST_RENDERING_SCENARIO` which keeps this harness disabled.
private struct HomePerfActionHarness: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        HStack(spacing: 0) {
            Button {
                store.send(.showToast(.warning(message: "perf-toast")))
            } label: {
                Text(verbatim: "T")
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("feature.home.perf.toast-show")

            Button {
                store.toast = nil
            } label: {
                Text(verbatim: "X")
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("feature.home.perf.toast-dismiss")

            Button {
                var next = store.calendarDate
                next.goToNextMonth()
                store.send(.setCalendarDate(next))
            } label: {
                Text(verbatim: "▶")
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("feature.home.perf.calendar-next")

            Button {
                var prev = store.calendarDate
                prev.goToPreviousMonth()
                store.send(.setCalendarDate(prev))
            } label: {
                Text(verbatim: "◀")
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("feature.home.perf.calendar-prev")
        }
        .opacity(0.05)
    }
}

// MARK: - PERF Toast Presentation Harness

/// PERF-only modifier used by Pass 3 **probe scenarios**. Observes
/// `store.toast` and exposes a deterministic state-change marker. In
/// production this modifier returns `content` unchanged so HomeView's
/// read-set never includes `toast`.
///
/// **Probe context**: production HomeView does not observe `toast` (the
/// field is displayed at the MainTab level in the production app shell).
/// This modifier adds an artificial UITEST-only observation path so the
/// toast probe scenario can exercise observation scoping experiments. The
/// scenario is therefore **not representative of the user's real rendering
/// path**, and the resulting XCTest numbers must not be cited as UI
/// Rendering improvement evidence.
///
/// Avoids `.txToast(item:)` because its 3-second auto-dismiss would add
/// non-deterministic state changes during measurement. The lightweight
/// overlay captures the same observation cost (HomeView body re-evaluating
/// on `toast` mutation) without auto-dismiss noise.
private struct PerfToastPresentationHarness: ViewModifier {
    @Binding var toast: TXToastType?

    func body(content: Content) -> some View {
        if UITestMode.isProbeScenario {
            content
                .overlay(alignment: .bottom) {
                    if toast != nil {
                        Color.clear.frame(width: 1, height: 1)
                    }
                }
                .perfStateMarker(
                    slug: "home",
                    key: "toast",
                    value: toast == nil ? "hidden" : "visible"
                )
        } else {
            content
        }
    }
}

/// Wraps `perfCounterMarkers` so the counter accessibility overlays only
/// attach in probe scenarios. Rendering / smoke launches see no marker
/// overlays at all.
private struct PerfHomeCounterMarkersHarness: ViewModifier {
    func body(content: Content) -> some View {
        if UITestMode.isProbeScenario {
            content.perfCounterMarkers(
                slug: "home",
                keys: ["home.view.rebuild.proxy"]
            )
        } else {
            content
        }
    }
}
