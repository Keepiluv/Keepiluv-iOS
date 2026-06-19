//
//  GoalDetailView.swift
//  FeatureGoalDetail
//
//  Created by 정지훈 on 1/21/26.
//

import SwiftUI
import UIKit

import ComposableArchitecture
import FeatureGoalDetailInterface
import FeatureProofPhotoInterface
import SharedDesignSystem
import SharedPerfTestingSupport

import Kingfisher

/// 목표 상세 화면을 렌더링하는 View입니다.
///
/// ## 사용 예시
/// ```swift
/// GoalDetailView(
///     store: Store(
///         initialState: GoalDetailReducer.State()
///     ) {
///         GoalDetailReducer(
///             proofPhotoReducer: ProofPhotoReducer()
///         )
///     }
/// )
/// ```
public struct GoalDetailView: View {
    
    @Bindable public var store: StoreOf<GoalDetailReducer>
    @Dependency(\.proofPhotoFactory) private var proofPhotoFactory
    @State private var rectFrame: CGRect = .zero
    @State private var keyboardFrame: CGRect = .zero
    @StateObject private var myEmojiFlyingReactionEmitter = FlyingReactionEmitter()
    @State private var dragState = GoalDetailDragState()
    
    /// GoalDetailView를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let view = GoalDetailView(
    ///     store: Store(
    ///         initialState: GoalDetailReducer.State(
    ///             currentUser: .mySelf,
    ///             id: 1,
    ///             verificationDate: "2026-02-07"
    ///         )
    ///     ) {
    ///         GoalDetailReducer(proofPhotoReducer: ProofPhotoReducer())
    ///     }
    /// )
    /// ```
    public init(store: StoreOf<GoalDetailReducer>) {
        self.store = store
    }
    
    public var body: some View {
        GeometryReader { _ in
            ZStack {
                mainContent

                if store.isEditing && store.isCommentFocused {
                    dimmedView
                        .ignoresSafeArea()
                }

                if shouldShowCommentOverlay {
                    floatingCommentOverlay
                }

                if store.isShowReactionBar {
                    reactionBar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(.keyboard)
        .background(Color.Common.white)
        .toolbar(.hidden, for: .navigationBar)
        .observeKeyboardFrame($keyboardFrame)
        .onAppear {
            store.send(.view(.onAppear))
        }
        .onDisappear {
            myEmojiFlyingReactionEmitter.clear()
            store.send(.view(.onDisappear))
        }
        .fullScreenCover(
            isPresented: $store.isPresentedProofPhoto,
            onDismiss: { store.send(.view(.proofPhotoDismissed)) },
            content: {
                if let proofPhotoStore = store.scope(state: \.proofPhoto, action: \.proofPhoto) {
                    proofPhotoFactory.makeView(proofPhotoStore)
                        .perfReadyMarker("goal-detail-to-proof-photo")
                }
            }
        )
        .cameraPermissionAlert(
            isPresented: $store.isCameraPermissionAlertPresented,
            onDismiss: { store.send(.view(.cameraPermissionAlertDismissed)) }
        )
        .overlay(alignment: .bottom) {
            myEmojiFlyingReactionOverlay
        }
        .txToast(item: $store.toast, customPadding: 54)
        .txLoading(isPresented: store.isLoading || store.isSavingPhotoLog)
    }
}

// MARK: - SubViews
private extension GoalDetailView {
    var mainContent: some View {
        VStack(spacing: 0) {
            navigationBar
                .zIndex(1)

            if store.isFetchFailed {
                DataRetryView {
                    store.send(.view(.dataRetryTapped))
                }
            } else {
                refreshableGoalContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var refreshableGoalContent: some View {
        ZStack(alignment: .top) {
            ProgressView()
                .padding(.top, 16)
                .opacity(dragState.pullOffset > 0 || store.isRefreshing ? 1 : 0)

            VStack(spacing: 0) {
                if store.item != nil {
                    cardView
                        .padding(.horizontal, 27)
                        .padding(.top, Constants.cardTopPadding)

                    if store.isCompleted {
                        completedBottomContent
                    } else if store.currentCompletedGoal?.status != .completed {
                        bottomButton
                            .padding(.top, 105)
                            .overlay(alignment: .bottomLeading) {
                                pokeImage
                                    .offset(x: 79, y: -45)
                            }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: dragState.pullOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .simultaneousGesture(pullToRefreshGesture)
    }

    var navigationBar: some View {
        TXNavigationBar(
            style: .subContent(
                .init(
                    title: store.goalName,
                    rightContent: store.naviBarRightText.isEmpty
                    ? nil
                    : .text(store.naviBarRightText)
                )
            ),
            onAction: { action in
                store.send(.view(.navigationBarTapped(action)))
            }
        )
    }
    
    var cardView: some View {
        ZStack {
            cardFrameReader

            myCard
                .zIndex(effectiveIsFrontMyCard ? 1 : 0)
            
            partnerCard
                .zIndex(effectiveIsFrontMyCard ? 0 : 1)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard !store.isEditing else { return }
                    dragState.updateCard(
                        translation: value.translation,
                        velocityWidth: value.velocity.width,
                        maxCardOffset: Constants.maxCardOffset,
                        dragVelocityThreshold: Constants.dragVelocityThreshold,
                        minimumDragResistance: Constants.minimumDragResistance
                    )
                }
                .onEnded { value in
                    guard !store.isEditing else { return }
                    guard dragState.axis != .vertical else {
                        dragState.resetCard()
                        return
                    }
                    guard dragState.shouldCompleteCardSwipe(
                        translation: value.translation,
                        velocityWidth: value.velocity.width,
                        dragVelocityThreshold: Constants.dragVelocityThreshold,
                        minimumDragResistance: Constants.minimumDragResistance
                    ) else {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.94)) {
                            dragState.reset()
                        }
                        return
                    }

                    withAnimation(.spring(response: 0.2, dampingFraction: 0.94)) {
                        dragState.reset()
                        store.send(.view(.cardSwiped))
                    }
                }
        )
    }

    var cardFrameReader: some View {
        Color.clear
            .frame(width: Constants.cardSize, height: Constants.cardSize)
            .readSize { rectFrame = $0 }
    }
    
    @ViewBuilder
    var myCard: some View {
        cardFace(
            isFront: effectiveIsFrontMyCard,
            isCompleted: store.myCardIsCompleted,
            imageData: store.pendingEditedImageData,
            imageURL: store.myCard?.imageUrl,
            showsMyEmoji: effectiveIsFrontMyCard && store.selectedReactionEmoji != nil
        )
        .offset(x: dragState.cardOffset * (effectiveIsFrontMyCard ? 1 : -1))
    }
    
    @ViewBuilder
    var partnerCard: some View {
        cardFace(
            isFront: !effectiveIsFrontMyCard,
            isCompleted: store.partnerCardIsCompleted,
            imageData: nil,
            imageURL: store.partnerCard?.imageUrl,
            showsMyEmoji: false
        )
        .offset(x: dragState.cardOffset * (effectiveIsFrontMyCard ? -1 : 1))
        .rotationEffect(.degrees(-8))
    }
    
    @ViewBuilder
    var completedBottomContent: some View {
        if store.isEditing {
            bottomButton
                .padding(.top, 101)
                .padding(.horizontal, 30)
        } else {
            createdAtText
                .padding(.top, 14)
                .padding(.trailing, 36)
        }
    }
    
    var createdAtText: some View {
        Text(store.createdAt)
            .typography(.b4_12b)
            .foregroundStyle(Color.Gray.gray300)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    @ViewBuilder var reactionBar: some View {
        ReactionBarView(
            selectedEmoji: store.selectedReactionEmoji,
            onSelect: { emoji in
                store.send(.view(.reactionEmojiTapped(emoji)))
            }
        )
        .padding(.horizontal, Constants.reactionBarHorizontalPadding)
        .position(
            x: rectFrame.midX,
            y: rectFrame.maxY
                + Constants.reactionBarTopPadding
                + Constants.reactionBarHeight / 2
        )
    }
    
    var backgroundCard: some View {
        let shape = RoundedRectangle(cornerRadius: 20)
        
        return shape
            .fill(Color.Gray.gray200)
            .insideBorder(
                Color.Gray.gray500,
                shape: shape,
                lineWidth: 1.6
            )
            .frame(width: Constants.cardSize, height: Constants.cardSize)
            .clipShape(shape)
    }
    
    @ViewBuilder
    func cardFace(
        isFront: Bool,
        isCompleted: Bool,
        imageData: Data?,
        imageURL: String?,
        showsMyEmoji: Bool
    ) -> some View {
        ZStack {
            backgroundCard
                .opacity(isFront ? 0 : 1)
            
            frontCardContent(
                isCompleted: isCompleted,
                imageData: imageData,
                imageURL: imageURL,
                showsMyEmoji: showsMyEmoji
            )
            .opacity(isFront ? 1 : 0)
        }
    }
    
    @ViewBuilder
    func frontCardContent(
        isCompleted: Bool,
        imageData: Data?,
        imageURL: String?,
        showsMyEmoji: Bool
    ) -> some View {
        if isCompleted {
            completedImageCard(
                imageData: imageData,
                imageURL: imageURL,
                showsMyEmoji: showsMyEmoji
            )
        } else {
            nonCompletedCard
                .overlay {
                    nonCompletedText
                }
        }
    }

    var nonCompletedCard: some View {
        let shape = RoundedRectangle(cornerRadius: 20)

        return Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                shape
                    .fill(Color.Common.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(shape)
            .insideBorder(
                Color.Gray.gray500,
                shape: shape,
                lineWidth: 1.6
            )
    }

    @ViewBuilder
    func completedImageCard(
        imageData: Data?,
        imageURL: String?,
        showsMyEmoji: Bool
    ) -> some View {
        if let imageData,
           let editedImage = UIImage(data: imageData) {
            completedImageCardContainer(
                showsMyEmoji: showsMyEmoji
            ) {
                Image(uiImage: editedImage)
                    .resizable()
                    .scaledToFill()
            }
        } else if let imageURL,
                  let url = URL(string: imageURL) {
            completedImageCardContainer(
                showsMyEmoji: showsMyEmoji
            ) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
            }
        } else {
            backgroundCard
        }
    }
    
    var nonCompletedText: some View {
        Text(store.emptyCardText)
            .typography(.h2_24r)
            .foregroundStyle(Color.Gray.gray500)
            .multilineTextAlignment(.center)
    }
    
    var pokeImage: some View {
        Image.Illustration.poke
            .resizable()
            .frame(width: 184, height: 160)
    }

    var bottomButton: some View {
        TXButton(
            shape: .round(
                style: .illustLight(text: store.bottomButtonText),
                size: store.isEditing ? .l : .m,
                state: .standard
            ),
            onTap: {
                store.send(.view(.bottomButtonTapped))
            }
        )
        .perfControl(slug: "goal-detail", element: "primary-cta")
    }

    @ViewBuilder
    func commentCircle(comment: String) -> some View {
        TXCommentCircle(
            commentText: store.isEditing ? $store.commentText : .constant(comment),
            isEditable: store.isEditing,
            isFocused: $store.isCommentFocused,
            onFocused: { isFocused in
                store.send(.view(.focusChanged(isFocused)))
            }
        )
    }

    var shouldShowCommentOverlay: Bool {
        guard effectiveFrontCardIsCompleted, rectFrame != .zero else { return false }
        return store.isEditing || !currentFrontComment.isEmpty
    }

    var currentFrontComment: String {
        if effectiveIsFrontMyCard {
            return store.myCard?.comment ?? ""
        } else {
            return store.partnerCard?.comment ?? ""
        }
    }

    var floatingCommentOverlay: some View {
        GeometryReader { rootGeo in
            let rootFrame = rootGeo.frame(in: .global)
            let posX = rectFrame.minX - rootFrame.minX
            let posY = rectFrame.minY - rootFrame.minY

            commentCircle(comment: currentFrontComment)
                .padding(.bottom, 26)
                .frame(width: rectFrame.width, height: rectFrame.height, alignment: .bottom)
                .rotationEffect(frontCardRotation)
                .offset(x: posX + dragState.cardOffset, y: posY - keyboardInset)
                .animation(.easeOut(duration: 0.25), value: keyboardInset)
        }
    }

    var dimmedView: some View {
        Color.Dimmed.dimmed70
            .opacity(store.isEditing && store.isCommentFocused ? 1 : 0)
            .transition(.opacity)
            .animation(.easeInOut, value: store.isCommentFocused)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .onTapGesture {
                store.send(.view(.dimmedBackgroundTapped))
            }
    }

    func completedImageCardContainer<Content: View>(
        showsMyEmoji: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20)
        
        return Color.clear
            .frame(width: Constants.cardSize, height: Constants.cardSize)
            .overlay {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .clipShape(shape)
            .insideBorder(
                Color.Gray.gray500,
                shape: shape,
                lineWidth: 1.6
            )
            .overlay(alignment: .topTrailing) {
                if showsMyEmoji {
                    myEmoji
                }
            }
    }
    
    @ViewBuilder
    var myEmoji: some View {
        if let emoji = store.selectedReactionEmoji?.image {
            emoji
                .resizable()
                .frame(width: 52, height: 52)
                .padding(
                    .init(
                        top: 5,
                        leading: 11,
                        bottom: 19,
                        trailing: 13
                    )
                )
                .background(
                    Image.Shape.emojiBubble
                        .frame(width: 76, height: 76)
                )
                .offset(x: 19, y: -14)
        } else {
            EmptyView()
        }
    }

    var myEmojiFlyingReactionOverlay: some View {
        GeometryReader { proxy in
            FlyingReactionOverlay(
                reactions: myEmojiFlyingReactionEmitter.reactions,
                alignment: .bottom
            )
            .onChange(of: store.selectedReactionEmoji) {
                playMyEmojiAppearAnimationIfNeeded(
                    containerWidth: proxy.size.width,
                    containerHeight: proxy.size.height
                )
            }
        }
        .allowsHitTesting(false)
    }

    func playMyEmojiAppearAnimationIfNeeded(
        containerWidth: CGFloat,
        containerHeight: CGFloat
    ) {
        guard store.shouldShowMyEmojiAnimation,
              let selectedEmoji = store.selectedReactionEmoji else { return }
        myEmojiFlyingReactionEmitter.emit(
            emoji: selectedEmoji,
            config: .goalDetailBottom(
                width: containerWidth,
                height: containerHeight
            )
        )
        store.send(.view(.myEmojiAppearAnimationPlayed))
    }
}

// MARK: - Methods
private extension GoalDetailView {
    var pullToRefreshGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !store.isEditing,
                      !store.isRefreshing,
                      !store.isLoading else { return }

                dragState.updatePull(
                    translation: value.translation,
                    maxOffset: Constants.maxPullToRefreshOffset
                )
            }
            .onEnded { _ in
                guard dragState.axis != .horizontal else { return }

                let shouldRefresh = dragState.shouldRefresh(
                    threshold: Constants.pullToRefreshThreshold
                )

                withAnimation(.spring(response: 0.2, dampingFraction: 0.94)) {
                    dragState.reset()
                }

                guard shouldRefresh,
                      !store.isEditing,
                      !store.isRefreshing,
                      !store.isLoading else { return }

                store.send(.view(.refreshPulled))
            }
    }

    var effectiveIsFrontMyCard: Bool {
        dragState.isCrossingDuringCardDrag ? !store.isFrontMyCard : store.isFrontMyCard
    }

    var keyboardInset: CGFloat {
        max(0, rectFrame.maxY - keyboardFrame.minY)
    }

    var frontCardRotation: Angle {
        effectiveIsFrontMyCard ? .degrees(0) : .degrees(-8)
    }

    var effectiveFrontCardIsCompleted: Bool {
        effectiveIsFrontMyCard ? store.myCardIsCompleted : store.partnerCardIsCompleted
    }

}

// MARK: - Constants
private extension GoalDetailView {
    enum Constants {
        static var isSEDevice: Bool {
            UIScreen.main.bounds.height <= 667
        }
        
        static let maxCardOffset: CGFloat = 100
        static let dragVelocityThreshold: CGFloat = 1200
        static let minimumDragResistance: CGFloat = 0.35
        static let pullToRefreshThreshold: CGFloat = 80
        static let maxPullToRefreshOffset: CGFloat = 120
        static var cardTopPadding: CGFloat { isSEDevice ? 34 : 89 }
        static var cardSize: CGFloat { isSEDevice ? 321 : 336 }
        static let reactionBarHeight: CGFloat = 77
        static let reactionBarHorizontalPadding: CGFloat = 20
        static var reactionBarTopPadding: CGFloat { isSEDevice ? 19 : 69 }
    }
}

private extension FlyingReactionConfig {
    static func goalDetailBottom(width: CGFloat, height: CGFloat) -> Self {
        let xSpread = max(60, (width / 2) - 24)
        let maxTravel = max(220, height - 40)
        return FlyingReactionConfig(
            emojiCount: 30,
            startXRange: (-xSpread)...xSpread,
            startYRange: -12...6,
            durationRange: 1.05...1.55,
            delayStep: 0.03,
            delayJitterRange: 0...0.02,
            heightRange: (300)...maxTravel,
            amplitudeRange: 8...18,
            frequencyRange: 0.7...1.2,
            driftRange: -20...20,
            scaleRange: 0.78...1.08,
            wobbleRange: 1...3
        )
    }
}

#Preview {
    GoalDetailView(
        store: Store(
            initialState: GoalDetailReducer.State(
                currentUser: .mySelf,
                id: 1,
                verificationDate: "2026-02-07"
            ),
            reducer: { }
        )
    )
}
