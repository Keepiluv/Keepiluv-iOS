//
//  GoalDetailDragState.swift
//  FeatureGoalDetail
//
//  Created by Codex on 6/17/26.
//

import CoreGraphics

enum GoalDetailDragAxis {
    case vertical
    case horizontal
}

struct GoalDetailDragState {
    var axis: GoalDetailDragAxis?
    var pullOffset: CGFloat = .zero
    var cardOffset: CGFloat = .zero
    var isCrossingDuringCardDrag: Bool = false

    mutating func updatePull(
        translation: CGSize,
        maxOffset: CGFloat
    ) {
        resolveAxisIfNeeded(translation)

        guard axis == .vertical, translation.height > 0 else {
            pullOffset = .zero
            return
        }

        pullOffset = min(translation.height, maxOffset)
    }

    func shouldRefresh(threshold: CGFloat) -> Bool {
        pullOffset >= threshold
    }

    mutating func updateCard(
        translation: CGSize,
        velocityWidth: CGFloat,
        maxCardOffset: CGFloat,
        dragVelocityThreshold: CGFloat,
        minimumDragResistance: CGFloat
    ) {
        resolveAxisIfNeeded(translation)

        guard axis == .horizontal else {
            resetCard()
            return
        }

        let width = resistedDragWidth(
            for: translation.width,
            velocity: velocityWidth,
            dragVelocityThreshold: dragVelocityThreshold,
            minimumDragResistance: minimumDragResistance
        )

        guard abs(width) >= abs(translation.height) else {
            resetCard()
            return
        }

        let maximumOffset = maxCardOffset * 2
        guard (-maximumOffset...maximumOffset).contains(width) else {
            return
        }

        cardOffset = repeatedCardOffset(
            for: width,
            maxCardOffset: maxCardOffset
        )
        isCrossingDuringCardDrag = shouldCrossCards(
            for: width,
            maxCardOffset: maxCardOffset
        )
    }

    func shouldCompleteCardSwipe(
        translation: CGSize,
        velocityWidth: CGFloat,
        dragVelocityThreshold: CGFloat,
        minimumDragResistance: CGFloat
    ) -> Bool {
        guard axis == .horizontal else { return false }

        let width = resistedDragWidth(
            for: translation.width,
            velocity: velocityWidth,
            dragVelocityThreshold: dragVelocityThreshold,
            minimumDragResistance: minimumDragResistance
        )
        return abs(width) >= abs(translation.height)
    }

    mutating func resetCard() {
        cardOffset = .zero
        isCrossingDuringCardDrag = false
    }

    mutating func reset() {
        axis = nil
        pullOffset = .zero
        resetCard()
    }

    private mutating func resolveAxisIfNeeded(_ translation: CGSize) {
        guard axis == nil else { return }

        axis = abs(translation.height) >= abs(translation.width)
            ? .vertical
            : .horizontal
    }

    private func repeatedCardOffset(
        for width: CGFloat,
        maxCardOffset: CGFloat
    ) -> CGFloat {
        let direction: CGFloat = width >= 0 ? 1 : -1
        let progress = abs(width).truncatingRemainder(dividingBy: maxCardOffset * 2)
        let offset = progress <= maxCardOffset ? progress : maxCardOffset * 2 - progress

        return offset * direction
    }

    private func shouldCrossCards(
        for width: CGFloat,
        maxCardOffset: CGFloat
    ) -> Bool {
        abs(width).truncatingRemainder(dividingBy: maxCardOffset * 2) > maxCardOffset
    }

    private func resistedDragWidth(
        for proposedWidth: CGFloat,
        velocity: CGFloat,
        dragVelocityThreshold: CGFloat,
        minimumDragResistance: CGFloat
    ) -> CGFloat {
        let speed = abs(velocity)
        guard speed > dragVelocityThreshold else {
            return proposedWidth
        }

        let overflow = min(
            (speed - dragVelocityThreshold) / dragVelocityThreshold,
            1
        )
        let resistance = 1 - (overflow * (1 - minimumDragResistance))
        return proposedWidth * resistance
    }
}
