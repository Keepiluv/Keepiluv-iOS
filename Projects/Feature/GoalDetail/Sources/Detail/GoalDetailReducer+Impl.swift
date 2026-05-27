//
//  GaolDetailReducer.swift
//  FeatureGoalDetail
//
//  Created by 정지훈 on 1/21/26.
//

import Foundation

import ComposableArchitecture
import CoreAnalyticsInterface
import CoreCaptureSessionInterface
import DomainGoalInterface
import DomainPhotoLogInterface
import FeatureGoalDetailInterface
import FeatureProofPhotoInterface
import SharedDesignSystem
import SharedUtil

private enum PokeCancelID: Hashable {
    case poke(Int64)
}

private enum PokeCooldownManager {
    private static let userDefaultsKey = "pokeCooldownTimestamps"
    private static let cooldownInterval: TimeInterval = 3 * 60 * 60

    static func remainingCooldown(goalId: Int64) -> TimeInterval? {
        guard let timestamps = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: TimeInterval],
              let lastPokeTime = timestamps[String(goalId)] else {
            return nil
        }
        let elapsed = Date().timeIntervalSince1970 - lastPokeTime
        let remaining = cooldownInterval - elapsed
        return remaining > 0 ? remaining : nil
    }

    static func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(ceil(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)시간 \(minutes)분"
        } else if hours > 0 {
            return "\(hours)시간"
        } else {
            return "\(max(1, minutes))분"
        }
    }

    static func recordPoke(goalId: Int64) {
        var timestamps = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: TimeInterval] ?? [:]
        timestamps[String(goalId)] = Date().timeIntervalSince1970
        UserDefaults.standard.set(timestamps, forKey: userDefaultsKey)
    }

    static func removePoke(goalId: Int64) {
        var timestamps = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: TimeInterval] ?? [:]
        timestamps.removeValue(forKey: String(goalId))
        UserDefaults.standard.set(timestamps, forKey: userDefaultsKey)
    }
}

extension GoalDetailReducer {
    // swiftlint: disable function_body_length
    /// 실제 로직을 포함한 GoalDetailReducer를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = GoalDetailReducer(
    ///     proofPhotoReducer: ProofPhotoReducer()
    /// )
    /// ```
    public init(
        proofPhotoReducer: ProofPhotoReducer
    ) {
        @Dependency(\.captureSessionClient) var captureSessionClient
        @Dependency(\.goalClient) var goalClient
        @Dependency(\.photoLogClient) var photoLogClient
        @Dependency(\.analyticsClient) var analyticsClient
        
        let timeFormatter = RelativeTimeFormatter()
        
        // swiftlint: disable closure_body_length
        let reducer = Reduce<GoalDetailReducer.State, GoalDetailReducer.Action> { state, action in
            switch action {
                // MARK: - LifeCycle
            case .view(.onAppear):
                let date = state.verificationDate
                let goalId = state.goalId
                
                return .run { send in
                    do {
                        let item = try await goalClient.fetchGoalDetail(date, goalId)
                        await send(.response(.fethedGoalDetailItem(item)))
                    } catch {
                        await send(.response(.fetchGoalDetailFailed))
                    }
                }
                
            case .view(.onDisappear):
                return .none
                
                // MARK: - Action
            case .view(.bottomButtonTapped):
                if state.currentCompletedGoal?.status == .completed {
                    return .send(.presentation(.showToast(.warning(message: "끝난 목표는 인증이 불가능해요!"))))
                }
                let shouldGoToProofPhoto = (state.currentUser == .mySelf && !state.isCompleted) || state.isEditing
                if shouldGoToProofPhoto {
                    return .run { send in
                        let isAuthorized = await captureSessionClient.fetchIsAuthorized()
                        await send(.response(.authorizationCompleted(isAuthorized: isAuthorized)))
                    }
                }
                guard state.currentUser == .you, !state.isCompleted else { return .none }
                let goalId = state.currentGoalId
                if let remaining = PokeCooldownManager.remainingCooldown(goalId: goalId) {
                    let timeText = PokeCooldownManager.formatRemainingTime(remaining)
                    return .send(.presentation(.showToast(.warning(message: "\(timeText) 뒤에 다시 찌를 수 있어요"))))
                }
                return .run { send in
                    PokeCooldownManager.recordPoke(goalId: goalId)
                    do {
                        try await goalClient.pokePartner(goalId)
                        analyticsClient.logEvent(GoalDetailAnalyticsEvent.pokeSent)
                        await send(.presentation(.showToast(.poke(message: "상대방을 찔렀어요!"))))
                    } catch {
                        PokeCooldownManager.removePoke(goalId: goalId)
                        await send(.presentation(.showToast(.warning(message: "찌르기에 실패했어요"))))
                    }
                }
                .debounce(id: PokeCancelID.poke(goalId), for: .milliseconds(300), scheduler: DispatchQueue.main)

            case let .view(.navigationBarTapped(action)):
                if case .backTapped = action {
                    return .send(.delegate(.navigateBack))
                } else if case .rightTapped = action {
                    if state.isEditing {
                        return .send(.internal(.updatePhotoLog))
                    } else {
                        state.isEditing = true
                        state.commentText = state.comment
                    }
                }
                return .none
                
            case let .view(.reactionEmojiTapped(reactionEmoji)):
                guard state.currentUser == .you else { return .none }
                guard state.selectedReactionEmoji != reactionEmoji else { return .none }
                guard let photoLogId = state.currentCard?.photologId else { return .none }
                let previousReaction = state.currentCard?.reaction
                state.selectedReactionEmoji = reactionEmoji
                return .concatenate(
                    .send(.response(.updateCurrentCardReaction(reactionEmoji.rawValue))),
                    .run { send in
                        do {
                            let request = PhotoLogUpdateReactionRequestDTO(reaction: reactionEmoji.rawValue)
                            _ = try await photoLogClient.updateReaction(photoLogId, request)
                            analyticsClient
                                .logEvent(
                                    GoalDetailAnalyticsEvent.emojiReactionSent(emoji: reactionEmoji.rawValue)
                                )
                        } catch {
                            await send(.response(.reactionUpdateFailed(previousReaction: previousReaction)))
                        }
                    }
                )
                
            case .view(.cardSwiped):
                state.currentUser = state.currentUser == .mySelf ? .you : .mySelf
                state.commentText = state.comment
                state.selectedReactionEmoji = state.currentCard?.reaction.flatMap(ReactionEmoji.init(from:))
                state.createdAt = timeFormatter.displayText(from: state.currentCard?.createdAt)
                
                return .none
                
            case let .view(.focusChanged(isFocused)):
                state.isCommentFocused = isFocused
                return .none
                
            case .view(.dimmedBackgroundTapped):
                state.isCommentFocused = false
                return .none
                
                // MARK: - State Update
            case let .response(.fethedGoalDetailItem(item)):
                state.item = item
                if let goalIndex = state.completedGoalItems.firstIndex(where: {
                    $0.myPhotoLog?.goalId == state.goalId || $0.yourPhotoLog?.goalId == state.goalId
                }) {
                    state.currentGoalIndex = goalIndex
                } else {
                    state.currentGoalIndex = 0
                }
                state.commentText = state.comment
                state.selectedReactionEmoji = state.currentCard?.reaction.flatMap(ReactionEmoji.init(from:))
                state.createdAt = timeFormatter.displayText(from: state.currentCard?.createdAt)
                
                return .none
                
            case .response(.fetchGoalDetailFailed):
                return .send(.presentation(.showToast(.warning(message: "목표 상세 조회에 실패했어요"))))
                
            case let .response(.updateCurrentCardReaction(reaction)):
                guard state.currentUser == .you else { return .none }
                guard let item = state.item else { return .none }
                let targetGoalId = state.currentGoalId
                var updatedCompletedGoals = item.completedGoals
                
                guard let index = updatedCompletedGoals.firstIndex(where: { goal in
                    guard let goal else { return false }
                    return goal.myPhotoLog?.goalId == targetGoalId || goal.yourPhotoLog?.goalId == targetGoalId
                }) else { return .none }
                guard let currentGoal = updatedCompletedGoals[index] else { return .none }
                
                guard var yourPhotoLog = currentGoal.yourPhotoLog else { return .none }
                yourPhotoLog.reaction = reaction
                updatedCompletedGoals[index] = GoalDetail.CompletedGoal(
                    goalName: currentGoal.goalName,
                    myPhotoLog: currentGoal.myPhotoLog,
                    yourPhotoLog: yourPhotoLog
                )
                
                state.item = GoalDetail(
                    partnerNickname: item.partnerNickname,
                    completedGoals: updatedCompletedGoals
                )
                return .none
                
            case let .response(.reactionUpdateFailed(previousReaction)):
                state.selectedReactionEmoji = previousReaction.flatMap(ReactionEmoji.init(from:))
                return .send(.presentation(.showToast(.warning(message: "리액션 전송에 실패했어요"))))

            case let .presentation(.showToast(toast)):
                state.toast = toast
                return .none
                
            case let .response(.authorizationCompleted(isAuthorized)):
                if !isAuthorized {
                    state.isCameraPermissionAlertPresented = true
                    return .none
                }
                state.isPresentedProofPhoto = true
                state.proofPhoto = ProofPhotoReducer.State(
                    goalId: state.currentGoalId,
                    comment: state.isEditing ? state.commentText : state.comment,
                    verificationDate: state.verificationDate,
                    isEditing: state.isEditing
                )
                
                return .none
                
            case .view(.cameraPermissionAlertDismissed):
                state.isCameraPermissionAlertPresented = false
                return .none
                
            case .internal(.updatePhotoLog):
                if let current = state.currentCard, state.currentUser == .mySelf {
                    guard let photologId = current.photologId else { return .none }
                    let pendingEditedImageData = state.pendingEditedImageData
                    let comment = state.commentText
                    let goalId = state.currentGoalId
                    let isCommentChanged = comment != current.comment
                    let isImageChanged = pendingEditedImageData != nil
                    if !isCommentChanged && !isImageChanged {
                        state.isEditing = false
                        return .none
                    }
                    state.isSavingPhotoLog = true
                    
                    return .run { send in
                        do {
                            var fileName: String
                            if let pendingEditedImageData {
                                let optimizedImageData = ImageUploadOptimizer.optimizedJPEGData(
                                    from: pendingEditedImageData
                                )
                                let uploadResponse = try await photoLogClient.fetchUploadURL(goalId)
                                try await photoLogClient.uploadImageData(
                                    optimizedImageData,
                                    uploadResponse.uploadUrl
                                )
                                fileName = uploadResponse.fileName
                            } else {
                                let imageURLString = current.imageUrl ?? ""
                                fileName = URL(string: imageURLString)?.lastPathComponent ?? imageURLString
                            }

                            let request = PhotoLogUpdateRequestDTO(
                                fileName: fileName,
                                comment: comment
                            )
                            try await photoLogClient.updatePhotoLog(photologId, request)
                            await send(.binding(.set(\.isEditing, false)))
                            await send(.binding(.set(\.isSavingPhotoLog, false)))
                        } catch {
                            await send(.binding(.set(\.isSavingPhotoLog, false)))
                            await send(.presentation(.showToast(.warning(message: "인증샷 수정에 실패했어요"))))
                        }
                    }
                }
                
                return .none
                
                // MARK: - Child Action
            case .proofPhoto(.delegate(.closeProofPhoto)):
                state.isPresentedProofPhoto = false
                return .none
                
            case let .proofPhoto(.delegate(.completedUploadPhoto(myPhotoLog, editedImageData))):
                state.isPresentedProofPhoto = false
                state.pendingEditedImageData = editedImageData
                var myPhotoLog = myPhotoLog
                myPhotoLog.goalName = state.goalName
                myPhotoLog.photologId = state.currentCard?.photologId
                
                return .send(.internal(.updateMyPhotoLog(myPhotoLog)))
                
            case .view(.proofPhotoDismissed):
                state.proofPhoto = nil
                return .none

            case let .internal(.updateMyPhotoLog(myPhotoLog)):
                guard let item = state.item else { return .none }

                let targetGoalId = myPhotoLog.goalId
                var updatedCompletedGoals = item.completedGoals
                
                if let index = updatedCompletedGoals.firstIndex(where: { card in
                    guard let card else { return false }
                    return card.myPhotoLog?.goalId == targetGoalId || card.yourPhotoLog?.goalId == targetGoalId
                }) {
                    let existing = updatedCompletedGoals[index]
                    updatedCompletedGoals[index] = GoalDetail.CompletedGoal(
                        goalName: existing?.goalName ?? myPhotoLog.goalName ?? "",
                        myPhotoLog: myPhotoLog,
                        yourPhotoLog: existing?.yourPhotoLog
                    )
                } else {
                    updatedCompletedGoals.append(
                        GoalDetail.CompletedGoal(
                            goalName: myPhotoLog.goalName ?? "",
                            myPhotoLog: myPhotoLog,
                            yourPhotoLog: nil
                        )
                    )
                }
                
                state.item = GoalDetail(
                    partnerNickname: item.partnerNickname,
                    completedGoals: updatedCompletedGoals
                )
                
                state.commentText = state.comment
                state.selectedReactionEmoji = state.currentCard?.reaction.flatMap(ReactionEmoji.init(from:))
                state.createdAt = timeFormatter.displayText(from: state.currentCard?.createdAt)
                
                return .none
                
            case .proofPhoto:
                return .none
                
            case .binding:
                return .none
                
            case .delegate:
                return .none
            }
        }
        // swiftlint: enable closure_body_length
        self.init(
            reducer: reducer,
            proofPhotoReducer: proofPhotoReducer
        )
    }
    // swiftlint: enable function_body_length
}
