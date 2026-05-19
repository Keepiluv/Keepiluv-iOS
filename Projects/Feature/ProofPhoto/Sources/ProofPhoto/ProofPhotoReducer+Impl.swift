//
//  ProofPhotoReducer+Impl.swift
//  FeatureProofPhoto
//
//  Created by 정지훈 on 1/22/26.
//

import AVFoundation
import ComposableArchitecture
import CoreAnalyticsInterface
import CoreCaptureSessionInterface
import CoreCrashlyticsInterface
import DomainGoalInterface
import DomainPhotoLogInterface
import FeatureProofPhotoInterface
import Foundation
import PhotosUI
import SharedDesignSystem
import SharedUtil

extension ProofPhotoReducer {
    // swiftlint: disable function_body_length
    /// 실제 로직을 포함한 ProofPhotoReducer를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = ProofPhotoReducer()
    /// ```
    public init() {
        @Dependency(\.captureSessionClient) var captureSessionClient
        @Dependency(\.photoLogClient) var photoLogClient
        @Dependency(\.analyticsClient) var analyticsClient
        @Dependency(\.crashlyticsClient) var crashlytics
        
        // swiftlint: disable closure_body_length
        let reducer = Reduce<ProofPhotoReducer.State, ProofPhotoReducer.Action> { state, action in
            switch action {
                
            // MARK: - Life Cycle
            case .onAppear:
                return .run { [isFlashOn = state.isFlashOn] send in
                    captureSessionClient.setFlashEnabled(isFlashOn)
                    let session = await captureSessionClient.setUpCaptureSession(.back)
                    analyticsClient.logEvent(ProofPhotoAnalyticsEvent.opened)
                    await send(.setupCaptureSessionCompleted(session: session))
                }
                
            // MARK: - Action
            case .closeButtonTapped:
                return .send(.delegate(.closeProofPhoto))

            case .captureButtonTapped:
                guard !state.isCapturing else { return .none }
                captureSessionClient.setFlashEnabled(state.isFlashOn)
                state.isCapturing = true
                return .run { send in
                    do {
                        let imageData = try await captureSessionClient.capturePhoto()

                        await send(.captureCompleted(imageData: imageData))
                        captureSessionClient.stopRunning()
                    } catch {
                        crashlytics.record(
                            error,
                            ProofPhotoCrashlyticsRecordEvent.captureFailed(
                                errorType: String(describing: error)
                            )
                        )
                        await send(.captureFailed)
                    }
                }
                
            case .switchButtonTapped:
                return .run { [isFront = state.isFront, isFlashOn = state.isFlashOn] send in
                    let isFront = !isFront
                    await captureSessionClient.switchCamera(isFront)
                    captureSessionClient.setFlashEnabled(isFlashOn)
                    
                    await send(.cameraSwitched)
                }
                
            case .flashButtonTapped:
                state.isFlashOn.toggle()
                captureSessionClient.setFlashEnabled(state.isFlashOn)
                return .none
                
            case let .commentTextChanged(text):
                state.commentText = String(text.prefix(5))
                return .none
                
            case .returnButtonTapped:
                state.imageData = nil
                state.previewImage = nil
                state.selectedPhotoItem = nil
                state.isCapturing = false
                let position: AVCaptureDevice.Position = state.isFront ? .front : .back
                
                return .run { [isFlashOn = state.isFlashOn] send in
                    let session = await captureSessionClient.setUpCaptureSession(position)
                    captureSessionClient.setFlashEnabled(isFlashOn)
                    await send(.setupCaptureSessionCompleted(session: session))
                }
                
            case let .focusChanged(isFocused):
                state.isCommentFocused = isFocused
                return .none
                
            case .uploadButtonTapped:
                guard !state.isUploading else { return .none }
                // 코멘트는 비워도 되지만, 입력할 경우 5글자여야 함
                let commentCount = state.commentText.count
                if commentCount > 0 && commentCount < 5 {
                    return .send(.showToast(.fit(message: "코멘트는 5글자로 입력해주세요!")))
                } else {
                    guard let imageData = state.imageData else {
                        return .none
                    }

                    let goalId = state.goalId
                    let comment = state.commentText
                    let verificationDate = state.verificationDate
                    
                    if state.isEditing {
                        let myPhotoLog = GoalDetail.CompletedGoal.PhotoLog(
                            goalId: goalId,
                            photologId: nil,
                            goalName: nil,
                            owner: .mySelf,
                            imageUrl: nil,
                            comment: comment,
                            reaction: nil,
                            createdAt: "방금"
                        )
                        return .send(
                            .delegate(
                                .completedUploadPhoto(
                                    myPhotoLog: myPhotoLog,
                                    editedImageData: imageData
                                )
                            )
                        )
                    }
                    
                    state.isUploading = true
                    
                    return .run { send in
                        let originalSize = imageData.count
                        var uploadStep: ProofPhotoUploadStep = .fetchURL
                        do {
                            let uploadStartedAt = Date()
                            let optimizedImageData = ImageUploadOptimizer.optimizedJPEGData(from: imageData)
                            crashlytics.log(ProofPhotoCrashlyticsLogEvent.uploadStep(
                                .fetchURL,
                                goalId: goalId,
                                imageBytes: nil
                            ))
                            let uploadResponse = try await photoLogClient.fetchUploadURL(goalId)

                            uploadStep = .uploadS3
                            crashlytics.log(ProofPhotoCrashlyticsLogEvent.uploadStep(
                                .uploadS3,
                                goalId: goalId,
                                imageBytes: optimizedImageData.count
                            ))
                            try await photoLogClient.uploadImageData(optimizedImageData, uploadResponse.uploadUrl)

                            uploadStep = .createLog
                            crashlytics.log(ProofPhotoCrashlyticsLogEvent.uploadStep(
                                .createLog,
                                goalId: goalId,
                                imageBytes: nil
                            ))
                            let createRequest = PhotoLogCreateRequestDTO(
                                goalId: goalId,
                                fileName: uploadResponse.fileName,
                                comment: comment,
                                verificationDate: verificationDate
                            )
                            let photoLog = try await photoLogClient.createPhotoLog(createRequest)
                            let myPhotoLog = GoalDetail.CompletedGoal.PhotoLog(
                                goalId: goalId,
                                photologId: photoLog.photologId,
                                goalName: nil,
                                owner: .mySelf,
                                imageUrl: photoLog.imageUrl,
                                comment: comment,
                                reaction: nil,
                                createdAt: "방금"
                            )
                            analyticsClient
                                .logEvent(
                                    ProofPhotoAnalyticsEvent.uploaded(
                                        .init(
                                            goalId: goalId,
                                            targetDate: verificationDate,
                                            durationMS: Date().timeIntervalSince(uploadStartedAt) * 1000,
                                            fileSizeKB: Double(optimizedImageData.count) / 1024
                                        )
                                    )
                                )
                            await send(
                                .delegate(
                                    .completedUploadPhoto(
                                        myPhotoLog: myPhotoLog,
                                        editedImageData: imageData
                                    )
                                )
                            )
                        } catch {
                            crashlytics.record(
                                error,
                                ProofPhotoCrashlyticsRecordEvent.uploadFailed(
                                    step: uploadStep,
                                    goalId: goalId,
                                    originalImageBytes: originalSize
                                )
                            )
                            await send(.uploadFailed)
                        }
                    }
                }
                
            case .dimmedBackgroundTapped:
                return .send(.focusChanged(false))
            
            // MARK: - Update State
            case let .setupCaptureSessionCompleted(session):
                state.captureSession = session
                return .none
                
            case .cameraSwitched:
                state.isFront.toggle()
                return .none
            
            case .binding(\.selectedPhotoItem):
                guard let selectedPhotoItem = state.selectedPhotoItem else {
                    state.imageData = nil
                    state.previewImage = nil
                    return .none
                }

                return .run { send in
                    if let imageData = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                        await send(.galleryPhotoLoaded(imageData: imageData))
                        captureSessionClient.stopRunning()
                    }
                }

            case let .galleryPhotoLoaded(imageData):
                state.imageData = imageData
                // P4-2: decode once at ingestion. `imageData` remains the
                // upload source-of-truth; preview branch renders from
                // `previewImage` so body re-evals never re-decode.
                state.previewImage = UIImage(data: imageData)
                return .none

            case let .captureCompleted(imageData: imageData):
                state.imageData = imageData
                state.previewImage = UIImage(data: imageData)
                state.isCapturing = false
                return .none
                
            case .captureFailed:
                state.isCapturing = false
                return .send(.showToast(.warning(message: "사진 촬영에 실패했어요")))

            case .uploadFailed:
                state.isUploading = false
                return .send(.showToast(.warning(message: "사진 업로드에 실패했어요")))

            case let .showToast(toast):
                state.toast = toast
                return .none

            case .binding:
                return .none
                
            default: return .none
            }
        }
        // swiftlint: enable closure_body_length

        self.init(reducer: reducer)
    }
    // swiftlint: enable function_body_length
}
