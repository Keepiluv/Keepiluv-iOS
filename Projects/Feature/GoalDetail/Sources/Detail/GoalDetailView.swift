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
    @State private var didPlayMyEmojiAppearAnimation = false
    @State private var cardOffset: CGFloat = .zero
    @State private var isCrossingDuringDrag: Bool = false
    
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
        VStack(spacing: 0) {
            navigationBar
                .zIndex(1)
            
            if store.item != nil {
                cardView
                    .padding(.horizontal, 27)
                    .padding(.top, isSEDevice ? 47 : 103)
                
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
        .ignoresSafeArea(.keyboard)
        .background(dimmedView)
        .toolbar(.hidden, for: .navigationBar)
        .observeKeyboardFrame($keyboardFrame)
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            didPlayMyEmojiAppearAnimation = false
            myEmojiFlyingReactionEmitter.clear()
            store.send(.onDisappear)
        }
        .fullScreenCover(
            isPresented: $store.isPresentedProofPhoto,
            onDismiss: { store.send(.proofPhotoDismissed) },
            content: {
                if let proofPhotoStore = store.scope(state: \.proofPhoto, action: \.proofPhoto) {
                    proofPhotoFactory.makeView(proofPhotoStore)
                        .perfReadyMarker("goal-detail-to-proof-photo")
                }
            }
        )
        .cameraPermissionAlert(
            isPresented: $store.isCameraPermissionAlertPresented,
            onDismiss: { store.send(.cameraPermissionAlertDismissed) }
        )
        .overlay(alignment: .bottom) {
            myEmojiFlyingReactionOverlay
        }
        .txToast(item: $store.toast, customPadding: 54)
        .txLoading(isPresented: store.isSavingPhotoLog)
    }
}

// MARK: - SubViews
private extension GoalDetailView {
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
                store.send(.navigationBarTapped(action))
            }
        )
        .overlay(dimmedView)
    }
    
    var cardView: some View {
        ZStack {
            myCard
                .zIndex(effectiveIsFrontMyCard ? 1 : 0)
            
            partnerCard
                .zIndex(effectiveIsFrontMyCard ? 0 : 1)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let translation = value.translation
                    let width = resistedDragWidth(
                        for: translation.width,
                        velocity: value.velocity.width
                    )
                    guard abs(width) >= abs(translation.height) else {
                        resetDragState()
                        return
                    }
                    
                    let maxOffset = Constants.maxCardOffset * 2
                    
                    guard (-maxOffset...maxOffset).contains(width) else {
                        return
                    }
                    
                    cardOffset = repeatedCardOffset(for: width)
                    isCrossingDuringDrag = shouldCrossCards(for: width)
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.94)) {
                        resetDragState()
                        store.send(.cardSwiped)
                    }
                }
        )
    }
    
    @ViewBuilder
    var myCard: some View {
        cardFace(
            isFront: effectiveIsFrontMyCard,
            isCompleted: store.myCardIsCompleted,
            imageData: store.pendingEditedImageData,
            imageURL: store.myCard?.imageUrl,
            comment: store.myCard?.comment ?? "",
            showsMyEmoji: effectiveIsFrontMyCard && store.selectedReactionEmoji != nil
        )
        .offset(x: cardOffset * (effectiveIsFrontMyCard ? 1 : -1))
    }
    
    @ViewBuilder
    var partnerCard: some View {
        cardFace(
            isFront: !effectiveIsFrontMyCard,
            isCompleted: store.partnerCardIsCompleted,
            imageData: nil,
            imageURL: store.partnerCard?.imageUrl,
            comment: store.partnerCard?.comment ?? "",
            showsMyEmoji: false
        )
        .offset(x: cardOffset * (effectiveIsFrontMyCard ? -1 : 1))
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
        
        if store.isShowReactionBar {
            reactionBar
                .padding(.top, isSEDevice ? 23 : 73)
                .padding(.horizontal, 20)
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
                store.send(.reactionEmojiTapped(emoji))
            }
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
            .frame(width: 336, height: 336)
            .overlay(dimmedView)
            .clipShape(shape)
    }
    
    @ViewBuilder
    func cardFace(
        isFront: Bool,
        isCompleted: Bool,
        imageData: Data?,
        imageURL: String?,
        comment: String,
        showsMyEmoji: Bool
    ) -> some View {
        ZStack {
            backgroundCard
                .opacity(isFront ? 0 : 1)
            
            frontCardContent(
                isCompleted: isCompleted,
                imageData: imageData,
                imageURL: imageURL,
                comment: comment,
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
        comment: String,
        showsMyEmoji: Bool
    ) -> some View {
        if isCompleted {
            completedImageCard(
                imageData: imageData,
                imageURL: imageURL,
                comment: comment,
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
            .overlay(dimmedView)
    }

    @ViewBuilder
    func completedImageCard(
        imageData: Data?,
        imageURL: String?,
        comment: String,
        showsMyEmoji: Bool
    ) -> some View {
        if let imageData,
           let editedImage = UIImage(data: imageData) {
            completedImageCardContainer(comment: comment, showsMyEmoji: showsMyEmoji) {
                Image(uiImage: editedImage)
                    .resizable()
                    .scaledToFill()
            }
        } else if let imageURL,
                  let url = URL(string: imageURL) {
            completedImageCardContainer(comment: comment, showsMyEmoji: showsMyEmoji) {
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
                store.send(.bottomButtonTapped)
            }
        )
        .perfControl(slug: "goal-detail", element: "primary-cta")
    }
    
    @ViewBuilder
    func commentCircle(comment: String) -> some View {
        let keyboardInset = max(0, rectFrame.maxY - keyboardFrame.minY)
        TXCommentCircle(
            commentText: store.isEditing ? $store.commentText : .constant(comment),
            isEditable: store.isEditing,
            keyboardInset: keyboardInset,
            isFocused: $store.isCommentFocused,
            onFocused: { isFocused in
                store.send(.focusChanged(isFocused))
            }
        )
        .animation(.easeOut(duration: 0.25), value: keyboardInset)
    }
    
    var dimmedView: some View {
        Color.Dimmed.dimmed70
            .opacity(store.isEditing && store.isCommentFocused ? 1 : 0)
            .transition(.opacity)
            .animation(.easeInOut, value: store.isCommentFocused)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .onTapGesture {
                store.send(.dimmedBackgroundTapped)
            }
    }

    func completedImageCardContainer<Content: View>(
        comment: String,
        showsMyEmoji: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20)
        
        return Color.clear
            .frame(width: 336, height: 336)
            .readSize { rectFrame = $0 }
            .overlay {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .overlay(dimmedView)
            .clipShape(shape)
            .overlay(alignment: .bottom) {
                if !comment.isEmpty {
                    commentCircle(comment: comment)
                        .padding(.bottom, 26)
                }
            }
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
        guard store.myHasEmoji,
              !didPlayMyEmojiAppearAnimation,
              let selectedEmoji = store.selectedReactionEmoji else { return }
        didPlayMyEmojiAppearAnimation = true
        myEmojiFlyingReactionEmitter.emit(
            emoji: selectedEmoji,
            config: .goalDetailBottom(
                width: containerWidth,
                height: containerHeight
            )
        )
    }
}

// MARK: - Methods
private extension GoalDetailView {
    var effectiveIsFrontMyCard: Bool {
        isCrossingDuringDrag ? !store.isFrontMyCard : store.isFrontMyCard
    }

    func repeatedCardOffset(for width: CGFloat) -> CGFloat {
        let maxOffset = Constants.maxCardOffset
        let direction: CGFloat = width >= 0 ? 1 : -1
        let progress = abs(width).truncatingRemainder(dividingBy: maxOffset * 2)
        let offset = progress <= maxOffset ? progress : maxOffset * 2 - progress
        
        return offset * direction
    }

    func shouldCrossCards(for width: CGFloat) -> Bool {
        abs(width).truncatingRemainder(dividingBy: Constants.maxCardOffset * 2) > Constants.maxCardOffset
    }

    func resistedDragWidth(for proposedWidth: CGFloat, velocity: CGFloat) -> CGFloat {
        let speed = abs(velocity)
        guard speed > Constants.dragVelocityThreshold else {
            return proposedWidth
        }

        let overflow = min(
            (speed - Constants.dragVelocityThreshold) / Constants.dragVelocityThreshold,
            1
        )
        let resistance = 1 - (overflow * (1 - Constants.minimumDragResistance))
        return proposedWidth * resistance
    }

    func resetDragState() {
        cardOffset = .zero
        isCrossingDuringDrag = false
    }
    
    // 다른곳에서도 쓸 때 Util로 빼기
    private var isSEDevice: Bool {
        UIScreen.main.bounds.height <= 667
    }
}

// MARK: - Constants
private extension GoalDetailView {
    enum Constants {
        static let maxCardOffset: CGFloat = 100
        static let dragVelocityThreshold: CGFloat = 1200
        static let minimumDragResistance: CGFloat = 0.35
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
