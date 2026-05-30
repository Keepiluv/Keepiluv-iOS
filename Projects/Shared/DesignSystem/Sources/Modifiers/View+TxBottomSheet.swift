//
//  View+TxBottomSheet.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 2/3/26.
//

import SwiftUI

public extension View {
    /// 뷰 하단에 커스텀 콘텐츠를 표시하는 바텀시트를 적용합니다.
    ///
    /// `isPresented` 바인딩 값에 따라 시트를 표시/닫기하며, 배경 탭으로 dismiss할 수 있습니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// @State private var isBottomSheetPresented = false
    ///
    /// SomeView()
    ///     .txBottomSheet(isPresented: $isBottomSheetPresented) {
    ///         VStack {
    ///             Text("Bottom Sheet")
    ///         }
    ///     }
    /// ```
    func txBottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        isDragEnabled: Bool = true,
        showDragIndicator: Bool = false,
        @ViewBuilder sheetContent: @escaping () -> SheetContent
    ) -> some View {
        modifier(
            TXBottomSheetModifier(
                isPresented: isPresented,
                isDragEnabled: isDragEnabled,
                showDragIndicator: showDragIndicator,
                sheetContent: sheetContent
            )
        )
    }
}

private struct TXBottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let isDragEnabled: Bool
    let showDragIndicator: Bool
    var sheetContent: () -> SheetContent

    @State private var isCoverPresented = false
    @State private var sheetOffset: CGFloat = UIScreen.main.bounds.height
    @State private var dimmedOpacity: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var isDismissing = false
    @State private var dismissalGeneration = 0
    private let animationDuration: TimeInterval = 0.2
    private let dragAreaHeight: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) {
                if isPresented {
                    dismissalGeneration += 1
                    isDismissing = false
                    if isCoverPresented {
                        presentAnimated()
                    } else {
                        isCoverPresented = true
                    }
                } else {
                    startDismiss()
                }
            }
            .fullScreenCover(
                isPresented: $isCoverPresented,
                onDismiss: {
                    resetSheetState()
                },
                content: {
                    ZStack(alignment: .bottom) {
                        sheetView
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .onAppear { presentAnimated() }
                    .presentationBackground { dimmedBackground }
                }
            )
            .transaction { transaction in
                if shouldDisableCoverTransactionAnimation {
                    transaction.disablesAnimations = true
                }
            }
    }
}

// MARK: - SubViews {
private extension TXBottomSheetModifier {
    var shouldDisableCoverTransactionAnimation: Bool {
        isDismissing || isCoverPresented != isPresented
    }

    var sheetView: some View {
        VStack(spacing: 0) {
            dragContainer
            sheetContent()
        }
        .padding(.bottom, TXSafeArea.inset(.bottom))
        .frame(maxWidth: .infinity, alignment: .bottom)
        .background(Color.Common.white)
        .overlay {
            Color.clear
                .accessibilityIdentifier("tx.bottom-sheet.content")
                .allowsHitTesting(false)
        }
        .clipShape(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: Radius.m, topTrailing: Radius.m))
        )
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateContentHeight(proxy.size.height)
                    }
                    .onChange(of: proxy.size.height) {
                        updateContentHeight(proxy.size.height)
                    }
            }
        }
        .offset(y: sheetOffset)
        .toolbar(.hidden, for: .tabBar)
    }
    
    var dragContainer: some View {
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: dragAreaHeight, maxHeight: dragAreaHeight)
                .contentShape(.rect)
            
            if showDragIndicator {
                RoundedRectangle(cornerRadius: 2.55)
                    .fill(Color.Gray.gray100)
                    .frame(width: 44, height: 6)
                    .padding(.vertical, 11)
            }
        }
        .accessibilityIdentifier("tx.bottom-sheet.drag-area")
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    sheetOffset = max(value.translation.height, 0)
                }
                .onEnded { value in
                    let threshold = contentHeight > 0 ? contentHeight / 3 : 120
                    let shouldDismiss = value.translation.height > threshold
                    || value.velocity.height > 500
                    
                    if shouldDismiss {
                        isPresented = false
                    } else {
                        sheetOffset = 0
                    }
                },
            isEnabled: isDragEnabled
        )
    }
    
    var dimmedBackground: some View {
        Color.Dimmed.dimmed70
            .opacity(dimmedOpacity)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { startDismiss() }
            .accessibilityIdentifier("tx.bottom-sheet.backdrop")
    }
}

// MARK: - Function
private extension TXBottomSheetModifier {
    func resetSheetState() {
        sheetOffset = UIScreen.main.bounds.height
        dimmedOpacity = 0
        isPresented = false
        isDismissing = false
        dismissalGeneration += 1
    }

    func presentAnimated() {
        let currentGeneration = dismissalGeneration

        Task { @MainActor in
            await Task.yield()
            guard currentGeneration == dismissalGeneration, isPresented else { return }

            withAnimation(.easeOut(duration: animationDuration)) {
                dimmedOpacity = 1
                sheetOffset = 0
            }
        }
    }
    
    func startDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        dismissalGeneration += 1
        let currentDismissalGeneration = dismissalGeneration

        if isPresented {
            isPresented = false
        }

        withAnimation(.easeInOut(duration: animationDuration)) {
            sheetOffset = UIScreen.main.bounds.height
            dimmedOpacity = 0
        }
        
        Task { @MainActor in
            try await Task.sleep(for: .seconds(animationDuration))
            guard currentDismissalGeneration == dismissalGeneration else { return }
            isCoverPresented = false
            isDismissing = false
        }
    }

    func updateContentHeight(_ newHeight: CGFloat) {
        guard newHeight > 0, abs(contentHeight - newHeight) > 0.5 else { return }
        contentHeight = newHeight
    }
}
