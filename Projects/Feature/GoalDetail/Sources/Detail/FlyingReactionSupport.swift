//
//  FlyingReactionSupport.swift
//  FeatureGoalDetail
//
//  Created by Jihun on 2/25/26.
//

import SwiftUI

import SharedDesignSystem

@MainActor
final class FlyingReactionEmitter: ObservableObject {
    @Published private(set) var reactions: [FlyingReactionParticle] = []

    func emit(
        emoji: ReactionEmoji,
        config: FlyingReactionConfig
    ) {
        let newReactions = (0..<config.emojiCount).map { order in
            FlyingReactionParticle(
                emoji: emoji,
                startX: .random(in: config.startXRange),
                startY: .random(in: config.startYRange),
                startDate: Date(),
                duration: .random(in: config.durationRange),
                delay: (Double(order) * config.delayStep) + .random(in: config.delayJitterRange),
                height: .random(in: config.heightRange),
                amplitude: .random(in: config.amplitudeRange),
                frequency: .random(in: config.frequencyRange),
                drift: .random(in: config.driftRange),
                phase: .random(in: 0...(CGFloat.pi * 2)),
                scale: .random(in: config.scaleRange),
                wobble: .random(in: config.wobbleRange)
            )
        }

        reactions.append(contentsOf: newReactions)

        let removeAt = (newReactions.map { $0.duration + $0.delay }.max() ?? 1.4) + 0.2

        Task { @MainActor [weak self] in
            try await Task.sleep(for: .seconds(removeAt))
            guard let self else { return }
            let ids = Set(newReactions.map(\.id))
            self.reactions.removeAll { ids.contains($0.id) }
        }
    }

    func clear() {
        reactions.removeAll()
    }
}

struct FlyingReactionOverlay: View {
    let reactions: [FlyingReactionParticle]
    let alignment: Alignment

    var body: some View {
        Group {
            if reactions.isEmpty {
                // Idle guard: when there are no active particles, do not
                // run the 60Hz TimelineView. Pass 2 trace identified the
                // unconditional TimelineView as a ~0.12% idle CPU draw.
                // When `.emit` adds particles the body re-evaluates and
                // the else branch starts a fresh TimelineView; when the
                // emitter clears the array we fall back to this branch
                // and the TimelineView stops ticking.
                Color.clear
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    ZStack(alignment: alignment) {
                        ForEach(reactions) { reaction in
                            let progress = reaction.progress(at: context.date)
                            if progress > 0, progress <= 1 {
                                reaction.emoji.image
                                    .offset(
                                        x: reaction.xOffset(at: progress),
                                        y: reaction.yOffset(at: progress)
                                    )
                                    .opacity(reaction.opacity(at: progress))
                                    .scaleEffect(reaction.scale)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct FlyingReactionConfig {
    let emojiCount: Int
    let startXRange: ClosedRange<CGFloat>
    let startYRange: ClosedRange<CGFloat>
    let durationRange: ClosedRange<Double>
    let delayStep: Double
    let delayJitterRange: ClosedRange<Double>
    let heightRange: ClosedRange<CGFloat>
    let amplitudeRange: ClosedRange<CGFloat>
    let frequencyRange: ClosedRange<CGFloat>
    let driftRange: ClosedRange<CGFloat>
    let scaleRange: ClosedRange<CGFloat>
    let wobbleRange: ClosedRange<CGFloat>
}

struct FlyingReactionParticle: Identifiable {
    let id = UUID()
    let emoji: ReactionEmoji
    let startX: CGFloat
    let startY: CGFloat
    let startDate: Date
    let duration: TimeInterval
    let delay: TimeInterval
    let height: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat
    let drift: CGFloat
    let phase: CGFloat
    let scale: CGFloat
    let wobble: CGFloat

    func progress(at now: Date) -> CGFloat {
        CGFloat((now.timeIntervalSince(startDate) - delay) / duration)
    }

    func xOffset(at progress: CGFloat) -> CGFloat {
        let angle = Double((progress * frequency * 2 * .pi) + phase)
        let wobbleAngle = Double((progress * (frequency + 0.8) * 2 * .pi) + phase * 0.6)
        return startX
            + (CGFloat(sin(angle)) * amplitude)
            + (CGFloat(sin(wobbleAngle)) * wobble)
            + (drift * progress)
    }

    func yOffset(at progress: CGFloat) -> CGFloat {
        startY - (height * progress)
    }

    func opacity(at progress: CGFloat) -> Double {
        if progress < 0.25 { return Double(progress / 0.25) }
        if progress < 0.52 { return 1 }
        return Double(max(0, 1 - ((progress - 0.52) / 0.48)))
    }
}
