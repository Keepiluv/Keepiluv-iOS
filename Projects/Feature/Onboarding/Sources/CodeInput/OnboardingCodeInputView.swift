//
//  OnboardingCodeInputView.swift
//  FeatureOnboarding
//
//  Created by Jiyong on 01/28/26.
//

import ComposableArchitecture
import SharedDesignSystem
import SwiftUI
import UIKit

/// 커플 연결 초대 코드 입력 화면입니다.
public struct OnboardingCodeInputView: View {
    @Bindable var store: StoreOf<OnboardingCodeInputReducer>
    @FocusState private var isTextFieldFocused: Bool

    public init(store: StoreOf<OnboardingCodeInputReducer>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            TXNavigationBar(style: .iconOnly(.back)) { action in
                if action == .backTapped {
                    store.send(.view(.backButtonTapped))
                }
            }

            ScrollView {
                VStack(spacing: 0) {
                    titleSection
                        .padding(.horizontal, Spacing.spacing9)
                        .padding(.bottom, 92)

                    bodyContent
                }
            }
            .scrollDismissesKeyboard(.interactively)

            Spacer()

            bottomButton
                .padding(.horizontal, Spacing.spacing8)
                .padding(.bottom, isTextFieldFocused ? Spacing.spacing6 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .onTapGesture {
            isTextFieldFocused = false
        }
        .txToast(item: $store.toast, customPadding: 76)
        .txLoading(isPresented: store.isLoading)
    }
}

// MARK: - Subviews

private extension OnboardingCodeInputView {
    var titleSection: some View {
        HStack {
            Text("""
                짝꿍에게 받은
                초대 코드를 써주세요
                """)
                .typography(.h3_22eb)
                .foregroundStyle(Color.Gray.gray500)
            Spacer()
        }
    }

    /// Figma: gap-[52px] between myInviteCodeCard and receivedCodeSection
    var bodyContent: some View {
        VStack(spacing: 52) {
            myInviteCodeCard
                .padding(.horizontal, Spacing.spacing12)

            receivedCodeSection
        }
    }

    /// Figma: py-[20px], gap-[6px], rounded-[12px]
    var myInviteCodeCard: some View {
        VStack(spacing: Spacing.spacing4) {
            Text("내 초대 코드")
                .typography(.b3_12eb)
                .foregroundStyle(Color.Gray.gray400)

            HStack(spacing: Spacing.spacing5) {
                Text(store.myInviteCode)
                    .typography(.h1_28b)
                    .foregroundStyle(Color.Gray.gray500)

                copyButton
            }
        }
        .padding(.vertical, Spacing.spacing8)
        .frame(maxWidth: .infinity)
        .background(Color.Common.white)
        .insideBorder(
            Color.Gray.gray200,
            shape: RoundedRectangle(cornerRadius: Radius.s),
            lineWidth: LineWidth.m
        )
    }

    var copyButton: some View {
        Button {
            store.send(.view(.copyMyCodeButtonTapped))
        } label: {
            Image.Icon.Symbol.copy
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.Gray.gray300)
                .padding(Spacing.spacing1)
                .background(Color.Gray.gray50)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
        }
        .buttonStyle(.plain)
    }

    /// Figma: gap-[12px], label is full-width centered, input fields have px-[36px]
    var receivedCodeSection: some View {
        VStack(spacing: Spacing.spacing6) {
            Text("받은 코드 쓰기")
                .typography(.b3_12eb)
                .foregroundStyle(Color.Gray.gray500)
                .frame(maxWidth: .infinity)

            codeInputFields
                .padding(.horizontal, Spacing.spacing12)
        }
    }

    /// Figma: justify-between for 8 cells
    var codeInputFields: some View {
        ZStack {
            hiddenTextField

            HStack(spacing: 0) {
                ForEach(0..<OnboardingCodeInputReducer.State.codeLength, id: \.self) { index in
                    if index > 0 {
                        Spacer(minLength: 0)
                    }
                    codeInputCell(at: index)
                }
            }
            .contentShape(Rectangle())
            .overlay {
                EditMenuOverlay(
                    onTap: {
                        store.send(.view(.codeFieldTapped))
                        isTextFieldFocused = true
                    },
                    onPaste: {
                        store.send(.view(.pasteCodeButtonTapped))
                    }
                )
            }
        }
    }

    var hiddenTextField: some View {
        TextField(
            "",
            text: Binding(
                get: { store.receivedCode },
                set: { store.send(.view(.codeInputChanged($0))) }
            )
        )
        .keyboardType(.asciiCapable)
        .textInputAutocapitalization(.characters)
        .focused($isTextFieldFocused)
        .frame(width: 1, height: 1)
        .opacity(0.01)
        .allowsHitTesting(false)
    }

    /// Figma: 36x58px per cell, radius-xs (8px)
    func codeInputCell(at index: Int) -> some View {
        let character = store.codeCharacters[index]
        let isFocused = store.focusedIndex == index && isTextFieldFocused
        let isFilled = character != nil

        return ZStack {
            RoundedRectangle(cornerRadius: Radius.xs)
                .fill(Color.Common.white)
                .insideBorder(
                    isFocused ? Color.Gray.gray500 : Color.Gray.gray200,
                    shape: RoundedRectangle(cornerRadius: Radius.xs),
                    lineWidth: LineWidth.m
                )

            if let char = character {
                Text(String(char))
                    .typography(.h3_22eb)
                    .foregroundStyle(Color.Gray.gray500)
            }

            if isFocused && !isFilled {
                cursor
            }
        }
        .frame(width: 36, height: 58)
    }

    var cursor: some View {
        Rectangle()
            .fill(Color.Gray.gray500)
            .frame(width: 2, height: 28)
            .clipShape(Capsule())
    }

    var bottomButton: some View {
        TXButton(
            shape: .rect(
                style: .basic(text: "완료"),
                size: .l,
                state: store.isCodeComplete ? .standard : .disabled
            ),
            onTap: { store.send(.view(.completeButtonTapped)) }
        )
        .disabled(!store.isCodeComplete)
    }
}

// MARK: - EditMenuOverlay

/// 시스템 기본 편집 메뉴(붙여넣기)를 표시하는 오버레이입니다.
private struct EditMenuOverlay: UIViewRepresentable {
    let onTap: () -> Void
    let onPaste: () -> Void

    func makeUIView(context: Context) -> EditMenuView {
        let view = EditMenuView()
        view.onTap = onTap
        view.onPaste = onPaste
        return view
    }

    func updateUIView(_ uiView: EditMenuView, context: Context) {
        uiView.onTap = onTap
        uiView.onPaste = onPaste
    }
}

private class EditMenuView: UIView, UIEditMenuInteractionDelegate {
    var onTap: (() -> Void)?
    var onPaste: (() -> Void)?
    private var editMenuInteraction: UIEditMenuInteraction?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupInteraction()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInteraction()
    }

    private func setupInteraction() {
        let interaction = UIEditMenuInteraction(delegate: self)
        addInteraction(interaction)
        editMenuInteraction = interaction

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        addGestureRecognizer(longPress)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onTap?()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let location = gesture.location(in: self)
        let configuration = UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
        editMenuInteraction?.presentEditMenu(with: configuration)
    }

    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        let pasteAction = UIAction(title: "붙여넣기", image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
            self?.onPaste?()
        }
        return UIMenu(children: [pasteAction])
    }
}
