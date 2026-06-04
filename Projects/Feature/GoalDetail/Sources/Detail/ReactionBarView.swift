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
                shadowView
                    .offset(y: 9)

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
    var shadowView: some View {
        Color.Gray.gray200
            .frame(maxWidth: 368)
            .frame(height: 68)
            .clipShape(.capsule)
    }
    
    func reactionBar(proxy: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(ReactionEmoji.allCases, id: \.self) { emoji in
                Group {
                    if case .happy = emoji {
                        firstButton(proxy: proxy, emoji: emoji)
                    } else if case .fuck = emoji {
                        lastButton(proxy: proxy, emoji: emoji)
                    } else {
                        rectButton(proxy: proxy, emoji: emoji)
                    }
                }
                .perfControl(slug: "goal-detail", element: "reaction-\(emoji.rawValue)")
            }
        }
        .background(Color.Gray.gray100)
        .frame(maxWidth: 368)
        .frame(height: 68)
        .clipShape(.capsule)
        .overlay(
            Capsule()
                .stroke(Color.Gray.gray500, lineWidth: 1)
        )
    }
    
    func firstButton(proxy: GeometryProxy, emoji: ReactionEmoji) -> some View {
        Button {
            onSelect(emoji)
            flyingReactionEmitter.emit(
                emoji: emoji,
                config: .reactionBar(width: proxy.size.width)
            )
        } label: {
            emoji.image
                .padding(.leading, 10)
                .padding(.trailing, 6)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 70, maxWidth: 84, maxHeight: .infinity)
        .background(selectedEmoji == emoji ? Color.Gray.gray300 : Color.clear)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 999, bottomLeadingRadius: 999))
    }
    
    func lastButton(proxy: GeometryProxy, emoji: ReactionEmoji) -> some View {
        Button {
            onSelect(emoji)
            flyingReactionEmitter.emit(
                emoji: emoji,
                config: .reactionBar(width: proxy.size.width)
            )
        } label: {
            emoji.image
                .padding(.leading, 3)
                .padding(.trailing, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 70, maxWidth: 84, maxHeight: .infinity)
        .background(selectedEmoji == emoji ? Color.Gray.gray300 : Color.clear)
        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 999, topTrailingRadius: 999))
    }
    
    func rectButton(proxy: GeometryProxy, emoji: ReactionEmoji) -> some View {
        Button {
            onSelect(emoji)
            flyingReactionEmitter.emit(
                emoji: emoji,
                config: .reactionBar(width: proxy.size.width)
            )
        } label: {
            emoji.image
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 70, maxWidth: 80, maxHeight: .infinity)
        .background(selectedEmoji == emoji ? Color.Gray.gray300 : Color.clear)
        .overlay(
            Rectangle()
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
