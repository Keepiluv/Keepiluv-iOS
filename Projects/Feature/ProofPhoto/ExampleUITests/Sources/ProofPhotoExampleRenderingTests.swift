import SharedPerfTestingSupportUITests
import XCTest

/// Pass 3 **rendering driver** UITests for FeatureProofPhotoExample.
///
/// These tests are NOT benchmarks. They drive deterministic UI activity so
/// that a real-device xctrace recording (Time Profiler + Animation Hitches)
/// captures the ProofPhoto preview + comment rendering path BEFORE the
/// upload step. XCTest pass/fail is not the metric.
///
/// ## Intended use
///
/// 1. Launch on a real device with seed `proof-photo-prefilled`. The
///    `ProofPhotoApp` injects a deterministic 1024×1024 JPEG fixture via
///    the production `.galleryPhotoLoaded` action so `store.imageData`
///    is populated without invoking the OS Photos picker. The fixture
///    image is generated procedurally at runtime — no binary asset in
///    the repo.
/// 2. Attach `xcrun xctrace record --attach FeatureProofPhotoExample`
///    once `feature.proof-photo.ready` exists.
/// 3. Stop the trace when the test reports completion.
///
/// ## Scope
///
/// - Measures the local preview + comment rendering path only.
/// - Does NOT use the real Photos picker.
/// - Does NOT use the camera.
/// - Does NOT trigger server upload (`photoLogClient` is a local no-op
///   mock injected by `ProofPhotoApp`).
/// - Does NOT change the image pipeline (no downsampling, no compression
///   refactor) — those are Phase 2 follow-up if needed.
///
/// ## Scenarios
///
/// - `testRendering_proofPhotoPreviewWithFixtureImage` — Pass 3 baseline,
///   1024×1024 procedural fixture, preview render + 6s idle window.
/// - `testRendering_proofPhotoCommentTyping` — Pass 3 baseline,
///   1024×1024 fixture, 5 ASCII keystroke window.
/// - `testRendering_proofPhotoPreviewWithLargeFixtureImage` — Pass 4 large
///   fixture (bundled 4032×3024 JPEG), preview render + 6s idle.
/// - `testRendering_proofPhotoCommentTypingWithLargeFixtureImage` — Pass 4
///   large fixture, 5 ASCII keystroke window.
/// - `testRendering_proofPhotoReselectFixtureImage` — Pass 4 large fixture,
///   dispatch a second large fixture via the production
///   `.galleryPhotoLoaded` action through the test harness button.
final class ProofPhotoExampleRenderingTests: XCTestCase {

    /// Drives preview render + 6s idle. Use Instruments to compare
    /// before/after image-decode / SwiftUI image-render cost.
    func testRendering_proofPhotoPreviewWithFixtureImage() {
        let app = XCUIApplication.launchForPerf(
            seed: "proof-photo-prefilled",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("proof-photo", timeout: 30)

        let preview = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.preview")
            .firstMatch
        XCTAssertTrue(
            preview.waitForExistence(timeout: 10),
            "feature.proof-photo.preview not visible — fixture image probably not loaded"
        )

        Thread.sleep(forTimeInterval: 6.0)
    }

    /// Focuses the comment circle and types 5 ASCII characters. Each
    /// character is delivered separately so the trace covers the
    /// per-keystroke rendering path (commentText mutation → text circle
    /// re-render + cursor TimelineView tick).
    func testRendering_proofPhotoCommentTyping() {
        let app = XCUIApplication.launchForPerf(
            seed: "proof-photo-prefilled",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("proof-photo", timeout: 30)

        // Wait for the preview, which is the gate for the comment overlay
        // to be visible (`shouldShowCommentOverlay = (captureSession != nil
        // || hasImage) && rectFrame != .zero`).
        let preview = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.preview")
            .firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10), "preview missing")

        let commentCircle = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.comment-circle")
            .firstMatch
        XCTAssertTrue(
            commentCircle.waitForExistence(timeout: 10),
            "feature.proof-photo.comment-circle not visible"
        )
        commentCircle.tap()

        // Type 5 ASCII characters via the focused TextField inside the
        // TXCommentCircle. ASCII chosen over 한글 to avoid IME instability
        // on simulator / device localization differences.
        for character in "abcde" {
            app.typeText(String(character))
        }

        // Verify the typed text actually reached `store.commentText`.
        // `perfStateMarker` exposes this only in PERF_TESTING builds; on a
        // real device whose current keyboard input mode is not ASCII the
        // typeText() calls above may be absorbed by the IME — the test
        // must fail honestly in that case so the trace is not collected
        // against an empty / wrong commentText. NOT optional.
        let typedMarker = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.marker.comment-text.abcde")
            .firstMatch
        XCTAssertTrue(
            typedMarker.waitForExistence(timeout: 10),
            "store.commentText never became 'abcde' — typing did not reach the field (likely IME / keyboard input mode). Scenario is not baseline-ready until this passes on the target device."
        )

        Thread.sleep(forTimeInterval: 2.0)
    }

    // MARK: - Pass 4 large-fixture scenarios

    /// Pass 4 preview render with 4032×3024 bundled JPEG (~7.5 MiB). Waits
    /// for `image-ingested.fixture-large` so xctrace attach happens after
    /// disk-read + initial ingestion is complete (fixture load cost stays
    /// out of the trace window per Pass 4 plan §A invalidation rule).
    func testRendering_proofPhotoPreviewWithLargeFixtureImage() {
        let app = XCUIApplication.launchForPerf(
            seed: "proof-photo-prefilled-large",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("proof-photo", timeout: 30)

        awaitIngested(app, source: "fixture-large", timeout: 30)
        awaitPreviewReady(app, timeout: 10)

        Thread.sleep(forTimeInterval: 6.0)
    }

    /// Pass 4 comment typing with 4032×3024 fixture rendered. Tests whether
    /// keystroke-induced body re-eval re-decodes the preview image (plan §P4-2
    /// entry-condition check).
    func testRendering_proofPhotoCommentTypingWithLargeFixtureImage() {
        let app = XCUIApplication.launchForPerf(
            seed: "proof-photo-prefilled-large",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("proof-photo", timeout: 30)

        awaitIngested(app, source: "fixture-large", timeout: 30)
        awaitPreviewReady(app, timeout: 10)

        let commentCircle = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.comment-circle")
            .firstMatch
        XCTAssertTrue(
            commentCircle.waitForExistence(timeout: 10),
            "feature.proof-photo.comment-circle not visible"
        )
        commentCircle.tap()

        for character in "abcde" {
            app.typeText(String(character))
        }

        let typedMarker = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.marker.comment-text.abcde")
            .firstMatch
        XCTAssertTrue(
            typedMarker.waitForExistence(timeout: 10),
            "store.commentText never became 'abcde' — typing did not reach the field (likely IME / keyboard input mode). Scenario is not baseline-ready until this passes on the target device."
        )

        Thread.sleep(forTimeInterval: 2.0)
    }

    /// Pass 4 reselect. Dispatches a second large fixture via the production
    /// `.galleryPhotoLoaded` action (through the example harness button) so
    /// the trace captures the real pre-upload image-replacement render path.
    /// Verifies the reselect.1 marker AND the second image's
    /// image-ingested marker per plan §E.
    func testRendering_proofPhotoReselectFixtureImage() {
        let app = XCUIApplication.launchForPerf(
            seed: "proof-photo-prefilled-large",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("proof-photo", timeout: 30)

        awaitIngested(app, source: "fixture-large", timeout: 30)
        awaitPreviewReady(app, timeout: 10)

        let reselectButton = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.test.reselect-button")
            .firstMatch
        XCTAssertTrue(
            reselectButton.waitForExistence(timeout: 10),
            "reselect harness button not present — seed/harness wiring broken"
        )
        reselectButton.tap()

        awaitIngested(app, source: "fixture-large-second", timeout: 10)

        let reselectMarker = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.marker.reselect.1")
            .firstMatch
        XCTAssertTrue(
            reselectMarker.waitForExistence(timeout: 5),
            "reselect counter never became 1 — production .galleryPhotoLoaded dispatch failed"
        )

        Thread.sleep(forTimeInterval: 4.0)
    }

    // MARK: - Helpers

    private func awaitIngested(
        _ app: XCUIApplication,
        source: String,
        timeout: TimeInterval
    ) {
        let marker = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.marker.image-ingested.\(source)")
            .firstMatch
        XCTAssertTrue(
            marker.waitForExistence(timeout: timeout),
            "image-ingested.\(source) marker not present within \(Int(timeout))s — fixture loading failed or seed wiring broken"
        )
    }

    private func awaitPreviewReady(_ app: XCUIApplication, timeout: TimeInterval) {
        let marker = app.descendants(matching: .any)
            .matching(identifier: "feature.proof-photo.marker.preview-ready.true")
            .firstMatch
        XCTAssertTrue(
            marker.waitForExistence(timeout: timeout),
            "preview-ready.true marker not present — image branch of photoPreview did not render"
        )
    }
}
