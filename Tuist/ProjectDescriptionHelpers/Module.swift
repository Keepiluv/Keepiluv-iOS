//
//  Module.swift
//  ProjectDescriptionHelpers
//
//  Created by 정지훈 on 12/18/25.
//

import ProjectDescription

/// Tuist 헬퍼 전반에서 사용하는 모듈 분류 네임스페이스입니다.
///
/// 모듈의 역할과 책임을 명확히 구분해 타겟 이름, 경로, 의존성 규칙을
/// 일관된 기준으로 생성하기 위해 사용됩니다.
public enum Module {
    case feature(Feature)
    case domain(Domain)
    case core(Core)
    case shared(Shared)
}

public extension Module {
    /// 실행 가능한 앱 타겟을 나타내는 모듈입니다.
    ///
    /// 실제 사용자에게 배포되는 진입점으로, 다른 모든 모듈을 조합해
    /// 최종 실행 바이너리를 구성하는 역할을 합니다.
    enum App: String, CaseIterable {
        case iOS
        
        /// 앱 타겟 이름의 기본 prefix입니다.
        public static let name: String = "Twix"
    }
    
    /// 앱과 함께 배포되는 확장(App Extension) 타겟을 나타내는 모듈입니다.
    ///
    /// 위젯, 공유 확장 등 앱의 기능을 보조하며,
    /// 앱 타겟과 번들 ID 및 배포 설정을 공유하는 경우가 많습니다.
    enum Extension: String, CaseIterable {
        case deletePlz
        
        /// 확장 타겟 이름의 기본 prefix입니다.
        public static let name: String = "Extension"
    }
}


public extension Module {
    /// 사용자 플로우를 담당하는 Feature 모듈입니다.
    ///
    /// 화면 단위 또는 사용자 플로우 단위로 구성되며,
    /// UI와 사용자 상호작용 로직을 중심으로 설계됩니다.
    enum Feature: String, CaseIterable {
        case common = "Common"
        case makeGoal = "MakeGoal"
        case notification = "Notification"
        case stats = "Stats"
        case settings = "Settings"
        case home = "Home"
        case proofPhoto = "ProofPhoto"
        case goalDetail = "GoalDetail"
        case auth = "Auth"
        case onboarding = "Onboarding"
        case mainTab = "MainTab"

        /// Feature 타겟 이름의 기본 prefix입니다.
        public static let name: String = "Feature"
    }
}

public extension Module {
    /// 비즈니스 로직 경계를 정의하는 Domain 모듈입니다.
    ///
    /// 앱의 핵심 규칙과 정책을 담으며,
    /// Feature에 의존하지 않고 독립적으로 설계되는 것이 원칙입니다.
    enum Domain: String, CaseIterable {
        case common = "Common"
        case notification = "Notification"
        case stats = "Stats"
        case photoLog = "PhotoLog"
        case goal = "Goal"
        case auth = "Auth"
        case onboarding = "Onboarding"

        /// Domain 타겟 이름의 기본 prefix입니다.
        public static let name: String = "Domain"
    }
}

public extension Module {
    /// 공통 인프라를 제공하는 Core 모듈입니다.
    ///
    /// 네트워크, 로깅, 저장소 등 기술적 기반을 담당하며,
    /// Feature/Domain에서 재사용되도록 설계됩니다.
    enum Core: String, CaseIterable {
        case analytics = "Analytics"
        case push = "Push"
        case captureSession = "CaptureSession"
        case network = "Network"
        case logging = "Logging"
        case storage = "Storage"
        case crashlytics = "Crashlytics"

        /// Core 타겟 이름의 기본 prefix입니다.
        public static let name: String = "Core"
    }
}

public extension Module {
    /// 여러 레이어에서 공통으로 사용하는 Shared 모듈입니다.
    ///
    /// 디자인 시스템, UI 컴포넌트, 범용 유틸리티 등을 포함합니다.
    enum Shared: String, CaseIterable {
        case util = "Util"
        case thirdPartyLib = "ThirdPartyLib"
        case designSystem = "DesignSystem"
        case perfTestingSupport = "PerfTestingSupport"
        
        /// Shared 타겟 이름의 기본 prefix입니다.
        public static let name: String = "Shared"
    }
}
