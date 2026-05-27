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
            ProofPhotoView(store: store)
                .perfRoot("proof-photo")
                .perfReadyMarker("proof-photo")
                .onAppear {
                    // Pre-load a deterministic fixture image so the
                    // rendering scenarios measure the preview + comment
                    // path without depending on the real Photos picker or
                    // camera capture. Dispatched via the production
                    // `.galleryPhotoLoaded` action — same code path a real
                    // gallery selection takes — so the measurement reflects
                    // the actual preview render flow.
                    guard UITestMode.isEnabled,
                          UITestMode.seedName == "proof-photo-prefilled" else { return }
                    store.send(.galleryPhotoLoaded(imageData: Self.perfFixtureImageData()))
                }
        }
    }

    /// Deterministic fixture image generated at runtime. Avoids checking a
    /// binary asset into the repo. 1024×1024 JPEG with a procedural
    /// gradient + grid pattern so it has enough non-trivial pixels to
    /// stress the preview pipeline (UIImage decode + SwiftUI image render
    /// + `scaledToFill` + rounded clip).
    private static func perfFixtureImageData() -> Data {
        let size = CGSize(width: 1024, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            // Vertical gradient
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
            // Diagonal grid to add high-frequency detail (more decode work)
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
