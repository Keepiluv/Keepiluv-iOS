//
//  ReactionBarView.swift
//  FeatureGoalDetail
//
//  Created by 정지훈 on 2/6/26.
//

import SwiftUI

import SharedDesignSystem
import SharedPerfTestingSupport

struct ReactionBarView: View {
    let selectedEmoji: ReactionEmoji?
    let onSelect: (ReactionEmoji) -> Void
    
    @StateObject private var flyingReactionEmitter = FlyingReactionEmitter()
    
    init(
        selectedEmoji: ReactionEmoji?,
        onSelect: @escaping (ReactionEmoji) -> Void
    ) {
        self.selectedEmoji = selectedEmoji
        self.onSelect = onSelect
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                shadowView(proxy: proxy)
                    .offset(y: 10)

                reactionBar(proxy: proxy)
            }
        }
        .frame(height: 77)
        .overlay(alignment: .bottomLeading) {
            FlyingReactionOverlay(
                reactions: flyingReactionEmitter.reactions,
                alignment: .bottomLeading
            )
        }
    }
}

// MARK: - SubViews

private extension ReactionBarView {
    func shadowView(proxy: GeometryProxy) -> some View {
        Color.Gray.gray200
            .frame(width: proxy.size.width, height: 67)
            .clipShape(.capsule)
    }
    
    func reactionBar(proxy: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(ReactionEmoji.allCases, id: \.self) { emoji in
                Button {
                    onSelect(emoji)
                    flyingReactionEmitter.emit(
                        emoji: emoji,
                        config: .reactionBar(width: proxy.size.width)
                    )
                } label: {
                    emoji.image
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selectedEmoji == emoji ? Color.Gray.gray300 : Color.clear)
                .perfControl(slug: "goal-detail", element: "reaction-\(emoji.rawValue)")
                
                if emoji != ReactionEmoji.allCases.last {
                    Rectangle()
                        .frame(width: 1)
                }
            }
        }
        .background(Color.Gray.gray100)
        .frame(width: proxy.size.width, height: 68)
        .clipShape(.capsule)
        .overlay(
            Capsule()
                .stroke(Color.Gray.gray500, lineWidth: 1)
        )
    }
}

private extension ReactionBarView {
    static func reactionBarConfig(width: CGFloat) -> FlyingReactionConfig {
        let minX: CGFloat = 8
        let maxXInset: CGFloat = 32
        let maxX = width - maxXInset
        return FlyingReactionConfig(
            emojiCount: 20,
            startXRange: minX...maxX,
            startYRange: -12 ... -12,
            durationRange: 0.85...1.35,
            delayStep: 0.04,
            delayJitterRange: 0...0.02,
            heightRange: 340...540,
            amplitudeRange: 10...22,
            frequencyRange: 0.6...1.1,
            driftRange: -28...28,
            scaleRange: 0.84...1.22,
            wobbleRange: 1...4
        )
    }
}

private extension FlyingReactionConfig {
    static func reactionBar(width: CGFloat) -> Self {
        ReactionBarView.reactionBarConfig(width: width)
    }
}
