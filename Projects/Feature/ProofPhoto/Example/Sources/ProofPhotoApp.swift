import AVFoundation
import ComposableArchitecture
import CoreCaptureSession
import CoreCaptureSessionInterface
import CoreCrashlyticsInterface
import DomainPhotoLogInterface
import FeatureProofPhoto
import FeatureProofPhotoInterface
import SharedPerfTestingSupport
import SwiftUI
import UIKit

/// Maps a `-UITEST_SEED` value to the initial fixture used by P4-0
/// rendering scenarios. Loading happens before the trace window via the
/// production `.galleryPhotoLoaded` action so generation/disk-read cost
/// is not measured inside the trace.
private enum ProofPhotoFixture {
    case procedural1024
    case bundledLarge
    case bundledLargeSecond

    static func forSeed(_ seedName: String?) -> ProofPhotoFixture? {
        switch seedName {
        case "proof-photo-prefilled":             return .procedural1024
        case "proof-photo-prefilled-large":       return .bundledLarge
        default:                                  return nil
        }
    }

    /// Stable identifier exposed via `feature.proof-photo.marker.image-ingested.<source>`.
    var source: String {
        switch self {
        case .procedural1024:      return "fixture"
        case .bundledLarge:        return "fixture-large"
        case .bundledLargeSecond:  return "fixture-large-second"
        }
    }

    var bundledResourceName: String? {
        switch self {
        case .procedural1024:      return nil
        case .bundledLarge:        return "proof-photo-prefilled-large"
        case .bundledLargeSecond:  return "proof-photo-prefilled-large-second"
        }
    }

    func data() -> Data {
        if let resourceName = bundledResourceName,
           let url = Bundle.main.url(forResource: resourceName, withExtension: "jpg"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return ProofPhotoFixture.procedural1024Data()
    }

    private static func procedural1024Data() -> Data {
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            for y in stride(from: 0, to: Int(size.height), by: 4) {
                let progress = CGFloat(y) / size.height
                let color = UIColor(
                    red: 0.20 + progress * 0.55,
                    green: 0.40,
                    blue: 0.80 - progress * 0.45,
                    alpha: 1.0
                )
                cg.setFillColor(color.cgColor)
                cg.fill(CGRect(x: 0, y: y, width: Int(size.width), height: 4))
            }
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            cg.setLineWidth(1)
            let step: CGFloat = 64
            for offset in stride(from: -size.height, through: size.width, by: step) {
                cg.move(to: CGPoint(x: offset, y: 0))
                cg.addLine(to: CGPoint(x: offset + size.height, y: size.height))
            }
            cg.strokePath()
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}

@main
struct ProofPhotoApp: App {
    /// Stored at App level so it survives `body` re-evaluations. The seed
    /// branching only injects fixture data — no captureSession / network
    /// changes — so we keep a single Store instance for the whole scene.
    private let store: StoreOf<ProofPhotoReducer>

    init() {
        UITestMode.configureApplication()
        self.store = Store(
            initialState: ProofPhotoReducer.State(
                goalId: 1,
                verificationDate: "2026-02-07"
            ),
            reducer: { ProofPhotoReducer() },
            withDependencies: {
                $0.captureSessionClient = UITestMode.isEnabled ? .perfMock : .liveValue
                $0.photoLogClient = .perfMock
                $0.crashlyticsClient = .previewValue
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            ExampleHost(store: store)
        }
    }
}

/// Example-only host. Owns markers + reselect harness so that ProofPhotoView
/// stays close to production behavior. Only `perfStateMarker`-style additions
/// to ProofPhotoView are inside `#if PERF_TESTING`, matching the Pass 3
/// pattern.
private struct ExampleHost: View {
    let store: StoreOf<ProofPhotoReducer>

    @State private var ingestedSource: String = "none"
    @State private var reselectCount: Int = 0

    var body: some View {
        ProofPhotoView(store: store)
            .perfRoot("proof-photo")
            .perfReadyMarker("proof-photo")
            .perfStateMarker(
                slug: "proof-photo",
                key: "image-ingested",
                value: ingestedSource
            )
            .perfStateMarker(
                slug: "proof-photo",
                key: "reselect",
                value: "\(reselectCount)"
            )
            .overlay(alignment: .top) { reselectTestHarness }
            .onAppear { performInitialIngestion() }
            .onChange(of: store.imageData) { oldValue, newValue in
                if oldValue != nil, newValue != nil {
                    reselectCount += 1
                }
            }
    }

    /// Dispatches the initial fixture via the production `.galleryPhotoLoaded`
    /// action. Same code path a real gallery selection takes. Runs before the
    /// xctrace window opens because the driver waits for
    /// `feature.proof-photo.marker.image-ingested.<source>` to appear.
    private func performInitialIngestion() {
        guard UITestMode.isEnabled,
              let fixture = ProofPhotoFixture.forSeed(UITestMode.seedName) else {
            return
        }
        let data = fixture.data()
        store.send(.galleryPhotoLoaded(imageData: data))
        ingestedSource = fixture.source
    }

    /// Hidden test-only harness. Exposes a tappable Color.clear region with
    /// an accessibility identifier. Tap dispatches the production
    /// `.galleryPhotoLoaded(imageData:)` action with a second fixture so the
    /// reselect scenario measures the real image-replacement path, not a
    /// synthetic state mutation.
    @ViewBuilder
    private var reselectTestHarness: some View {
        if UITestMode.isEnabled, UITestMode.seedName == "proof-photo-prefilled-large" {
            Color.clear
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    let fixture = ProofPhotoFixture.bundledLargeSecond
                    store.send(.galleryPhotoLoaded(imageData: fixture.data()))
                    ingestedSource = fixture.source
                }
                .accessibilityIdentifier("feature.proof-photo.test.reselect-button")
        } else {
            EmptyView()
        }
    }
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
    static let perfMock = Self(
        fetchUploadURL: { _ in .init(uploadUrl: "", fileName: "") },
        uploadImageData: { _, _ in },
        createPhotoLog: { request in
            .init(
                photologId: 1,
                goalId: request.goalId,
                imageUrl: "",
                comment: request.comment,
                verificationDate: request.verificationDate
            )
        },
        updateReaction: { _, request in
            .init(photologId: 1, reaction: request.reaction)
        },
        updatePhotoLog: { _, _ in },
        deletePhotoLog: { _ in }
    )
}
