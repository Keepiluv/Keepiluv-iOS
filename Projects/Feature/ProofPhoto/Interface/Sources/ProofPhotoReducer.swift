//
//  ProofPhotoReducer.swift
//  FeatureProofPhotoInterface
//
//  Created by 정지훈 on 1/22/26.
//

import AVFoundation
import Foundation
import PhotosUI
import SwiftUI

import ComposableArchitecture
import DomainGoalInterface
import SharedDesignSystem

/// ProofPhoto 화면의 상태와 액션을 정의하는 리듀서입니다.
@Reducer
public struct ProofPhotoReducer {
    let reducer: Reduce<State, Action>

    /// ProofPhoto 화면 렌더링에 필요한 상태입니다.
    @ObservableState
    public struct State: Equatable {
        public var titleText: String = "인증샷을 올려보세요~"
        public var commentText: String = ""
        public var isCommentFocused: Bool = false
        public var scopeText: String = "1x"
        public var captureSession: AVCaptureSession?
        public var imageData: Data?
        /// P4-2: decoded preview representation prepared once at ingestion.
        /// Renders the preview branch in `ProofPhotoView` without per-body
        /// `UIImage(data:)`. `imageData` remains the upload source of truth.
        /// Auto-derived `Equatable` uses NSObject pointer equality for
        /// `UIImage?` — stable between ingestions since we set it once.
        public var previewImage: UIImage?
        public var selectedPhotoItem: PhotosPickerItem?
        public var isFront: Bool = false
        public var isFlashOn: Bool = false
        public var isCapturing: Bool = false
        public var isUploading: Bool = false
        public var hasImage: Bool { imageData != nil }
        public var toast: TXToastType?
        public var goalId: Int64
        public var verificationDate: String
        public var isEditing: Bool

        /// 상태를 생성합니다.
        ///
        /// ## 사용 예시
        /// ```swift
        /// let state = ProofPhotoReducer.State(
        ///     goalId: 1,
        ///     comment: "응원합니다!",
        ///     verificationDate: "2026-02-07"
        /// )
        /// ```
        public init(
            goalId: Int64,
            comment: String = "",
            verificationDate: String,
            isEditing: Bool = false
        ) {
            self.goalId = goalId
            self.commentText = comment
            self.verificationDate = verificationDate
            self.isEditing = isEditing
        }
    }

    /// ProofPhoto 화면에서 발생하는 액션입니다.
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - View
        public enum View: Equatable {
            case onAppear
            case closeButtonTapped
            case captureButtonTapped
            case switchButtonTapped
            case flashButtonTapped
            case returnButtonTapped
            case focusChanged(Bool)
            case uploadButtonTapped
            case dimmedBackgroundTapped
            case commentTextChanged(String)
            case galleryPhotoLoaded(imageData: Foundation.Data)
        }

        // MARK: - Response
        public enum Response {
            case setupCaptureSessionCompleted(session: AVCaptureSession)
            case captureCompleted(imageData: Foundation.Data)
            case captureFailed
            case galleryPhotoLoaded(imageData: Foundation.Data)
            case cameraSwitched
            case uploadFailed
        }

        // MARK: - Presentation
        public enum Presentation: Equatable {
            case showToast(TXToastType)
        }

        // MARK: - Delegate
        case delegate(Delegate)

        /// ProofPhoto 화면에서 외부로 전달하는 이벤트입니다.
        public enum Delegate {
            case closeProofPhoto
            case completedUploadPhoto(
                myPhotoLog: GoalDetail.CompletedGoal.PhotoLog,
                editedImageData: Foundation.Data?
            )
        }

        case view(View)
        case response(Response)
        case presentation(Presentation)
    }

    /// 외부에서 주입된 Reduce로 리듀서를 구성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = ProofPhotoReducer(
    ///     reducer: Reduce { _, _ in .none }
    /// )
    /// ```
    public init(reducer: Reduce<State, Action>) {
        self.reducer = reducer
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        reducer
    }
}
