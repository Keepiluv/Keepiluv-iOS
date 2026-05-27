//
//  TargetTemplates.swift
//  ProjectDescriptionHelpers
//
//  Created by 정지훈 on 12/19/25.
//

import ProjectDescription

public extension Target {
    private static func featureExampleSlug(_ module: Module.Feature) -> String {
        switch module {
        case .auth:
            return "auth"
        case .goalDetail:
            return "goal-detail"
        case .home:
            return "home"
        case .mainTab:
            return "main-tab"
        case .makeGoal:
            return "make-goal"
        case .notification:
            return "notification"
        case .onboarding:
            return "onboarding"
        case .proofPhoto:
            return "proof-photo"
        case .settings:
            return "settings"
        case .stats:
            return "stats"
        case .common:
            return "common"
        }
    }

    /// Feature 모듈의 루트 타겟을 생성합니다.
    /// - Parameter config: 기본 설정을 담고 있는 `TargetConfig`입니다. Feature 루트 타겟에 맞게 일부 값이 수정됩니다.
    /// - Returns: Feature 루트 타겟 설정이 적용된 `Target`
    static func feature(config: TargetConfig) -> Self {
        var newConfig = config
        newConfig.name = Module.Feature.name
        return makeTarget(config: newConfig)
    }
    
    /// 특정 Feature 모듈의 구현 타겟을 생성합니다.
    /// - Parameters:
    ///   - module: 생성할 Feature 모듈 식별자입니다.
    ///   - config: 기본 설정을 담고 있는 `TargetConfig`입니다. 구현 타겟에 맞게 일부 값이 수정됩니다.
    /// - Returns: Feature 구현 타겟 설정이 적용된 `Target`
    static func feature(implements module: Module.Feature, config: TargetConfig) -> Self {
        var newConfig = config
        newConfig.name = Module.Feature.name + module.rawValue
        newConfig.sources = .sources
        
        return makeTarget(config: newConfig)
    }
    
    /// Feature 모듈의 유닛 테스트 타겟을 생성합니다.
    /// - Parameters:
    ///   - module: 테스트 타겟을 생성할 Feature 모듈 식별자입니다.
    ///   - config: 기본 설정을 담고 있는 `TargetConfig`입니다. 테스트 타겟에 맞게 일부 값이 수정됩니다.
    /// - Returns: Feature 유닛 테스트 타겟 설정이 적용된 `Target`
    static func feature(tests module: Module.Feature, config: TargetConfig) -> Self {
        var newConfig = config
        newConfig.name = Module.Feature.name + module.rawValue + "Tests"
        newConfig.product = .unitTests
        newConfig.sources = .tests
        
        return makeTarget(config: newConfig)
    }
    
    /// Feature 모듈의 테스트 지원 타겟을 생성합니다.
    /// - Parameters:
    ///   - module: 테스트 지원 타겟을 생성할 Feature 모듈 식별자입니다.
    ///   - config: 기본 설정을 담고 있는 `TargetConfig`입니다. 테스트 지원 타겟에 맞게 일부 값이 수정됩니다.
    /// - Returns: Feature 테스트 지원 타겟 설정이 적용된 `Target`
    static func feature(testing module: Module.Feature, config: TargetConfig) -> Self {
        var newConfig = config
        newConfig.name = Module.Feature.name + module.rawValue + "Testing"
        newConfig.sources = .testing
        
        return makeTarget(config: newConfig)
    }
    
    /// Feature 모듈의 인터페이스 타겟을 생성합니다.
    /// - Parameters:
    ///   - module: 인터페이스 타겟을 생성할 Feature 모듈 식별자입니다.
    ///   - config: 기본 설정을 담고 있는 `TargetConfig`입니다. 인터페이스 타겟에 맞게 일부 값이 수정됩니다.
    /// - Returns: Feature 인터페이스 타겟 설정이 적용된 `Target`
    static func feature(interface module: Module.Feature, config: TargetConfig) -> Self {
        var newConfig = config
        newConfig.name = Module.Feature.name + module.rawValue + "Interface"
        newConfig.sources = .interface
        
        return makeTarget(config: newConfig)
    }
    
    /// Feature 모듈의 예제 앱 타겟을 생성합니다.
    /// - Parameters:
    ///   - module: 예제 앱 타겟을 생성할 Feature 모듈 식별자입니다.
    ///   - config: 기본 설정을 담고 있는 `TargetConfig`입니다. 예제 앱 타겟에 맞게 일부 값이 수정됩니다.
    /// - Returns: Feature 예제 앱 타겟 설정이 적용된 `Target`
    static func feature(example module: Module.Feature, config: TargetConfig) -> Self {
        var newConfig = config
        let exampleName = Module.Feature.name + module.rawValue + "Example"
        newConfig.name = exampleName
        newConfig.sources = .exampleSources
        newConfig.product = .app
        newConfig.bundleId = Project.Environment.BundleId.bundlePrefix + ".example." + featureExampleSlug(module)
        newConfig.destinations = .iOS
        newConfig.resources = ["Resources/**"]
        newConfig.productName = exampleName
        newConfig.dependencies.append(.shared(implements: .perfTestingSupport))

        if let infoPlist = newConfig.infoPlist {
            newConfig.infoPlist = infoPlist
                .mergingLaunchScreenDefaults()
                .mergingExampleDisplayName("Example: \(module.rawValue)")
        } else {
            newConfig.infoPlist = .extendingDefault(
                with: Project.Environment.InfoPlist.launchScreen
            )
            .mergingExampleDisplayName("Example: \(module.rawValue)")
        }

        // Example 앱은 perf 측정용 독립 번들 ID를 automatic signing으로 관리합니다.
        newConfig.settings = .settings(
            base: [
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": "\(Project.Environment.BundleId.teamId)",
                "TARGETED_DEVICE_FAMILY": "1",
                "SUPPORTS_MACCATALYST": "NO",
                "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
                "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym"
            ]
        )

        return makeTarget(config: newConfig)
    }

    /// Feature 예제 앱의 smoke UITest 타겟을 생성합니다.
    static func feature(exampleUITests module: Module.Feature, config: TargetConfig = .init()) -> Self {
        var newConfig = config
        let exampleName = Module.Feature.name + module.rawValue + "Example"
        newConfig.name = exampleName + "UITests"
        newConfig.product = .uiTests
        newConfig.sources = "ExampleUITests/Sources/**"
        newConfig.bundleId = Project.Environment.BundleId.bundlePrefix
            + ".example."
            + featureExampleSlug(module)
            + ".uitests"
        newConfig.destinations = .iOS
        newConfig.dependencies = [
            .target(name: exampleName),
            .sharedPerfTestingSupportUITests
        ] + newConfig.dependencies
        newConfig.settings = .settings(
            base: [
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": "\(Project.Environment.BundleId.teamId)",
                "TARGETED_DEVICE_FAMILY": "1",
                "SUPPORTS_MACCATALYST": "NO",
                "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
                "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym"
            ]
        )

        return makeTarget(config: newConfig)
    }
}
