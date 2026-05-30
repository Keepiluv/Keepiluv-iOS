//
//  CalendarSheetModifier.swift
//  SharedDesignSystem
//
//  Created by Claude on 1/26/26.
//

import SwiftUI

// MARK: - Button Configuration

enum CalendarSheetButtonConfiguration<ButtonContent: View> {
    case `default`(text: String, onComplete: () -> Void)
    case custom(content: (_ exitPickerModeIfNeeded: @escaping () -> Bool) -> ButtonContent)
}

// MARK: - Constants

enum CalendarSheetConstants {
    static let dismissThreshold: CGFloat = 100
    static let backdropMaxOffset: CGFloat = 400
    static let backdropMaxOpacity: Double = 0.4
    static let dragVelocityThreshold: CGFloat = 500
    static let springResponse: Double = 0.35
    static let springDamping: Double = 0.86
    static let hiddenOffsetFallback: CGFloat = 1_000
}

// MARK: - Calendar Sheet Modifier

struct CalendarSheetModifier<ButtonContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var selectedDate: TXCalendarDate
    let buttonConfiguration: CalendarSheetButtonConfiguration<ButtonContent>
    let isDateEnabled: ((TXCalendarDateItem) -> Bool)?

    @State private var dragOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var containerSize: CGSize = .zero
    @State private var safeAreaBottom: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack {
                content

                Color.black
                    .opacity(isVisible ? backdropOpacity : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(isVisible)
                    .onTapGesture { dismissSheet() }

                VStack {
                    Spacer()
                    sheetContent
                }
                .offset(y: sheetOffset(containerHeight: geometry.size.height))
                .gesture(dragGesture)
                .allowsHitTesting(isVisible)
                .ignoresSafeArea(edges: .bottom)
            }
            .onAppear {
                containerSize = geometry.size
                safeAreaBottom = geometry.safeAreaInsets.bottom
                isVisible = isPresented
            }
            .onChange(of: geometry.size) { _, newSize in
                containerSize = newSize
            }
            .onChange(of: geometry.safeAreaInsets.bottom) { _, newValue in
                safeAreaBottom = newValue
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                dragOffset = 0
            }
            withAnimation(springAnimation) {
                isVisible = newValue
            }
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        VStack(spacing: 0) {
            Color.Common.white
                .frame(height: Spacing.spacing10)
                .clipShape(.rect(cornerRadii: topCornerRadii))
                .contentShape(Rectangle())

            calendarBottomSheet
        }
        .padding(.bottom, safeAreaBottom)
        .background(Color.Common.white)
        .clipShape(.rect(cornerRadii: topCornerRadii))
        .transaction { transaction in
            if dragOffset != 0 {
                transaction.animation = nil
            }
        }
    }

    @ViewBuilder
    private var calendarBottomSheet: some View {
        switch buttonConfiguration {
        case let .default(text, onComplete):
            TXCalendarBottomSheet(
                selectedDate: $selectedDate,
                completeButtonText: text,
                onComplete: onComplete,
                isDateEnabled: isDateEnabled
            )

        case let .custom(content):
            TXCalendarBottomSheet(
                selectedDate: $selectedDate,
                isDateEnabled: isDateEnabled,
                buttonContent: content
            )
        }
    }

    private var topCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(topLeading: Radius.m, topTrailing: Radius.m)
    }

    private var springAnimation: Animation {
        .spring(response: CalendarSheetConstants.springResponse, dampingFraction: CalendarSheetConstants.springDamping)
    }

    private var backdropOpacity: Double {
        let progress = min(max(dragOffset / CalendarSheetConstants.backdropMaxOffset, 0), 1)
        return CalendarSheetConstants.backdropMaxOpacity * (1 - progress)
    }

    private func sheetOffset(containerHeight: CGFloat) -> CGFloat {
        let hiddenOffset = containerHeight > 0 ? containerHeight : CalendarSheetConstants.hiddenOffsetFallback
        return (isVisible ? 0 : hiddenOffset) + dragOffset
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let shouldDismiss = value.translation.height > CalendarSheetConstants.dismissThreshold
                    || velocity > CalendarSheetConstants.dragVelocityThreshold

                if shouldDismiss {
                    dismissSheet()
                } else {
                    withAnimation(springAnimation) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismissSheet() {
        isPresented = false
    }
}
