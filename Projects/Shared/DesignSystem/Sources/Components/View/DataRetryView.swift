//
//  DataRetryView.swift
//  SharedDesignSystem
//
//  Created by 정지훈 on 6/5/26.
//

import SwiftUI

/// 데이터 로드 실패 상태에서 재시도 안내를 표시하는 View입니다.
///
/// ## 사용 예시
/// ```swift
/// DataRetryView {
///     store.send(.view(.dataRetryTapped))
/// }
/// ```
public struct DataRetryView: View {
    var onTap: () -> Void

    /// `DataRetryView`를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// DataRetryView {
    ///     store.send(.view(.dataRetryTapped))
    /// }
    /// ```
    ///
    /// - Parameter onTap: 재시도 버튼을 탭했을 때 실행할 동작입니다.
    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }
    
    public var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Image.Illustration.trash

                Text(Constants.title)
                    .typography(.t2_16b)
                    .padding(.top, Spacing.spacing5)

                Text(Constants.subTitle)
                    .typography(.c1_12r)
                    .foregroundStyle(Color.Gray.gray300)
                    .padding(.top, Spacing.spacing3)

                TXButton(
                    shape: .rect(
                        style: .round(text: Constants.buttonTitle),
                        size: .s,
                        state: .standard
                    ),
                    onTap: onTap
                )
                .padding(.top, Spacing.spacing8)
            }
            .frame(width: Constants.frameWidth)
            .position(
                x: proxy.size.width / 2,
                y: proxy.deviceCenterYInView
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color.Common.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension GeometryProxy {
    var deviceCenterYInView: CGFloat {
        let frame = frame(in: .global)
        let deviceCenterY = UIScreen.main.bounds.height / 2

        return min(
            max(0, deviceCenterY - frame.minY),
            size.height
        )
    }
}

private extension DataRetryView {
    enum Constants {
        static let title: String = "데이터를 불러오지 못했어요"
        static let subTitle: String = "잠시 후 다시 시도해 주세요"
        static let buttonTitle: String = "재시도"
        static let frameWidth: CGFloat = 212
    }
}

#Preview {
    DataRetryView(onTap: {  })
}
