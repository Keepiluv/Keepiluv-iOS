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
/// - `testRendering_proofPhotoPreviewWithFixtureImage` — preview render
///   stable + 6s idle window (captures any TimelineView-driven cursor
///   work inside the comment overlay and any image-render side effects).
/// - `testRendering_proofPhotoCommentTyping` — tap comment circle to
///   focus + type 5 ASCII characters one by one. Each character mutates
///   `store.commentText`, re-renders the comment circle, and the cursor
///   `TimelineView` runs while focused.
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
}
