//
//  TargetDependency+External.swift
//  ProjectDescriptionHelpers
//
//  Created by 정지훈 on 1/3/26.
//

import ProjectDescription

/// `TargetDependency`에 Swift Package Manager(SPM) 기반 의존성 접근자를 제공합니다.
///
/// 외부 Swift Package 의존성을 Tuist Target에서 일관된 방식으로 참조하기 위해 사용됩니다.
public extension TargetDependency {
    /// Swift Package Manager로 관리되는 여러 외부 라이브러리를 편리하게 관리하기 위한 타입입니다.
    ///
    /// 각 case는 SPM 패키지를 나타내며,
    /// `TargetDependency.external(dependency:)`와 유기적으로 사용됩니다.
    enum External: String {
        // Firebase: akaffenberger 미러는 product 단위로 노출하며 FirebaseCore는
        // 별도 product가 아닌 다른 Firebase product의 transitive 의존성으로 포함된다.
        // 따라서 FirebaseCore는 enum에 두지 않는다.
        case FirebaseAnalytics
        case FirebaseMessaging
        case FirebaseRemoteConfig
        case FirebaseCrashlytics

        case GoogleSignIn

        case KakaoSDKCommon
        case KakaoSDKAuth
        case KakaoSDKUser

        case KakaoSDKShare
        case KakaoSDKTalk
        case Lottie

        case Pulse
        case PulseUI
        case PulseProxy

        case Kingfisher

        case ComposableArchitecture
    }
    
    /// SPM 패키지를 편하게 참조하기 위한 메서드입니다.
    ///
    /// `TargetDependency.External` 타입에 등록된 SPM 패키지 이름을 통해 패키지를 참조합니다.
    static func external(dependency: External) -> TargetDependency {
        .external(name: dependency.rawValue, condition: .when([.ios]))
    }
}
