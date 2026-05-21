//
//  GoalCardView.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 1/20/26.
//

import SwiftUI

import Kingfisher

/// 목표 카드 UI를 구성하는 뷰입니다.
///
/// ## 사용 예시
/// ```swift
/// GoalCardView(
///     item: .init(
///         id: 1,
///         goalName: "목표 이름",
///         goalEmoji: .Icon.Illustration.exercise,
///         myCard: .init(isSelected: false),
///         yourCard: .init(isSelected: false)
///     ),
///     onHeaderTapped: { },
///     onCheckButtonTapped: { },
///     actionLeft: { },
///     actionRight: { }
/// )
/// ```
public struct GoalCardView: View {
    let item: GoalCardItem
    let onHeaderTapped: () -> Void
    let onCheckButtonTapped: () -> Void
    let actionLeft: () -> Void
    let actionRight: () -> Void
    
    public init(
        item: GoalCardItem,
        onHeaderTapped: @escaping () -> Void,
        onCheckButtonTapped: @escaping () -> Void,
        actionLeft: @escaping () -> Void,
        actionRight: @escaping () -> Void
    ) {
        self.item = item
        self.onHeaderTapped = onHeaderTapped
        self.onCheckButtonTapped = onCheckButtonTapped
        self.actionLeft = actionLeft
        self.actionRight = actionRight
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            CardHeaderView(
                title: item.goalName,
                iconImage: item.goalEmoji,
                isBordered: !item.myCard.isSelected && !item.yourCard.isSelected,
                onTap: onHeaderTapped
            ) {
                TXCheckButton(
                    isMyChecked: item.myCard.isSelected,
                    isCoupleChecked: item.yourCard.isSelected,
                    action: onCheckButtonTapped
                )
            }
            
            if item.myCard.isSelected || item.yourCard.isSelected {
                HStack(spacing: 0) {
                    myContent
                    Constants.borderColor
                        .frame(width: Constants.borderWidth)
                        .frame(maxHeight: .infinity)
                    yourContent
                }
                .background(Constants.contentBackgroundColor)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .outsideBorder(
            Constants.borderColor,
            shape: RoundedRectangle(cornerRadius: Constants.cornerRadius),
            lineWidth: Constants.borderWidth
        )
    }
}

// MARK: - SubViews
private extension GoalCardView {
    var myContent: some View {
        contentCell(
            item: item.myCard,
            placeholder: Constants.myPlaceHollder,
            bottomLeadingRadius: Constants.cornerRadius
        )
        .onTapGesture(perform: actionLeft)
    }
    
    @ViewBuilder
    var yourContent: some View {
        let hasImage = item.yourCard.imageURL != nil
        
        contentCell(
            item: item.yourCard,
            placeholder: Constants.yourPlaceHollder,
            buttonAction: hasImage ? nil : actionRight,
            bottomTrailingRadius: Constants.cornerRadius
        )
        .onTapGesture {
            if hasImage {
                actionRight()
            }
        }
    }
    
    @ViewBuilder
    func contentCell(
        item: GoalCardItem.Card,
        placeholder: Placeholder,
        buttonAction: (() -> Void)? = nil,
        bottomLeadingRadius: CGFloat = 0,
        bottomTrailingRadius: CGFloat = 0
    ) -> some View {
        let unEvenRoundedRect = UnevenRoundedRectangle(
            cornerRadii: .init(
                bottomLeading: bottomLeadingRadius,
                bottomTrailing: bottomTrailingRadius
            )
        )

        Group {
            if let imageURL = item.imageURL {
                KFImage(imageURL)
                    .resizable()
                    .placeholder { }
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: Constants.imageHeight)
                    .clipped()
            } else {
                unCompletedView(
                    placeholder: placeholder,
                    isButtonDisabled: item.isButtonDisabled,
                    buttonAction: buttonAction
                )
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: Constants.imageHeight)
            }
        }
        .clipShape(unEvenRoundedRect)
        .contentShape(Rectangle())
        .overlay(alignment: .bottomTrailing) {
            if let emoji = item.emoji {
                emojiImage(emoji: emoji)
            }
        }
    }
    
    func unCompletedView(
        placeholder: Placeholder,
        isButtonDisabled: Bool,
        buttonAction: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            placeholder.image
            
            if placeholder.isButton {
                TXButton(
                    shape: .round(
                        style: .illustLight(text: "찌르기!"),
                        size: .s,
                        state: isButtonDisabled ? .disabled : .standard
                    ),
                    onTap: { buttonAction?() }
                )
                .padding(.bottom, 14)
            } else {
                Text(placeholder.text)
                    .typography(.b4_12b)
                    .foregroundStyle(Color.Gray.gray500)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    func emojiImage(emoji: Image) -> some View {
        emoji
            .resizable()
            .frame(width: Constants.emojiSize.width, height: Constants.emojiSize.height)
            .padding([.bottom, .trailing], Constants.emojiPadding)
    }
}

private extension GoalCardView {
    struct Placeholder {
        let image: Image
        let text: String
        let isButton: Bool
    }
    
    enum Constants {
        static let contentBackgroundColor: Color = Color.Gray.gray50
        static let borderColor: Color = Color.Gray.gray500
        static let borderWidth: CGFloat = LineWidth.m
        static let cornerRadius: CGFloat = Radius.s
        static let imageHeight: CGFloat = 136
        static let emojiSize: CGSize = CGSize(width: 40, height: 40)
        static let emojiPadding: CGFloat = Spacing.spacing3
        
        static let myPlaceHollder: Placeholder = .init(
            image: Image.Illustration.keepiluv,
            text: "KEEP IT UP!",
            isButton: false
        )
        
        static let yourPlaceHollder: Placeholder = .init(
            image: Image.Illustration.poke,
            text: "찌르기!",
            isButton: true
        )
    }
}
