import SharedPerfTestingSupportUITests
import XCTest

/// Pass 3 **rendering driver** UITests for FeatureGoalDetailExample.
///
/// These tests are NOT benchmarks. They drive deterministic UI activity so
/// that a real-device xctrace recording (Time Profiler + Animation Hitches)
/// captures the GoalDetail rendering path. XCTest pass/fail and any timing
/// the harness prints are not the metric.
///
/// ## Intended use
///
/// 1. Launch on a real device. The test launches with
///    `-UITEST` + `-UITEST_RENDERING_SCENARIO` + `-UITEST_SEED default`
///    and `disableAnimations: false`. The GoalDetail Example app does not
///    have a PERF probe harness today, but rendering scenarios still
///    require the rendering launch flag so any future probe additions
///    stay gated off.
/// 2. Attach `xcrun xctrace record --attach FeatureGoalDetailExample`
///    once the driver has the GoalDetail view ready (UITest log shows
///    `feature.goal-detail.ready` exists).
/// 3. Stop the trace when the test reports completion.
///
/// ## Scenarios
///
/// - `testRendering_goalDetailInitialRender` — launch + idle window so the
///   trace covers initial render + `FlyingReactionOverlay.TimelineView`
///   continuously ticking at 60 Hz on an empty `reactions` array.
/// - `testRendering_goalDetailReactionRapidFire` — cycles through all five
///   `ReactionEmoji` cases, dispatching `.reactionEmojiTapped` for each.
///   Each tap mutates `state.selectedReactionEmoji`, fans out 20 flying
///   particles via the overlay, and posts to a local no-op
///   `photoLogClient.updateReaction` mock injected by
///   `GoalDetailExampleView`.
///
/// ## Determinism
///
/// - `goalClient.previewValue` returns a deterministic GoalDetail item; the
///   Example launches with `currentUser: .you` so the reaction bar is
///   guaranteed visible.
/// - PhotoLogClient is a local in-process mock (`PhotoLogClient.perfMock`)
///   so no network call is issued.
final class GoalDetailExampleRenderingTests: XCTestCase {

    /// Drives initial render + 7s idle window. Captures FlyingReactionOverlay
    /// TimelineView's 60 Hz idle cost — relevant to the GoalDetail "무겁게
    /// 느껴진다" VoC.
    func testRendering_goalDetailInitialRender() {
        let app = XCUIApplication.launchForPerf(
            seed: "default",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("goal-detail", timeout: 30)

        // 7s idle window. xctrace recording should cover this entirely.
        Thread.sleep(forTimeInterval: 7.0)
    }

    /// Cycles through all five reaction emojis and taps each repeatedly.
    /// Different emoji per tap so `state.selectedReactionEmoji != reactionEmoji`
    /// guard always passes and the reducer actually mutates state. Each tap
    /// emits 20 flying particles for ~0.85–1.35s, so consecutive taps keep
    /// FlyingReactionOverlay continuously busy.
    func testRendering_goalDetailReactionRapidFire() {
        let app = XCUIApplication.launchForPerf(
            seed: "default",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("goal-detail", timeout: 30)

        // 5 ReactionEmoji rawValues. Cycling these guarantees each tap
        // passes the `selectedReactionEmoji != reactionEmoji` guard so the
        // reducer mutates state on every tap (not just on the first).
        let reactionIdentifiers = [
            "feature.goal-detail.reaction-ICON_HAPPY",
            "feature.goal-detail.reaction-ICON_TROUBLE",
            "feature.goal-detail.reaction-ICON_LOVE",
            "feature.goal-detail.reaction-ICON_DOUBT",
            "feature.goal-detail.reaction-ICON_FUCK"
        ]
        var firstReactionExists = false
        for identifier in reactionIdentifiers {
            let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            if !firstReactionExists {
                firstReactionExists = element.waitForExistence(timeout: 10)
                XCTAssertTrue(firstReactionExists, "Reaction bar not visible: \(identifier) missing")
            } else {
                XCTAssertTrue(element.exists, "Missing reaction identifier: \(identifier)")
            }
        }

        // 8 cycles × 5 emojis = 40 taps total. Each tap triggers state
        // mutation + 20 particle emit + async no-op photoLogClient call.
        for _ in 0..<8 {
            for identifier in reactionIdentifiers {
                app.descendants(matching: .any)
                    .matching(identifier: identifier)
                    .firstMatch
                    .tap()
            }
        }
    }
}
