//
//  Target+Shared.swift
//  ProjectDescriptionHelpers
//
//  Created by 정지훈 on 12/19/25.
//

import ProjectDescription
public extension Target {
    /// Shared 모듈의 루트 타겟을 생성합니다.
    /// - Parameter config: 기본 설정을 담고 있는 `TargetConfig`입니다. Shared 루트 타겟에 맞게 일부 값이 수정됩니다.
    /// - Returns: Shared 루트 타겟 설정이 적용된 `Target`
    static func shared(config: TargetConfig) -> Self {
        var newConfig = config
        newConfig.name = Module.Shared.name
        
        return makeTarget(config: newConfig)
    }
    
    /// 특정 Shared 모듈의 구현 타겟을 생성합니다.
    /// - Parameters:
    ///   - module: 생성할 Shared 모듈 식별자입니다.
    ///   - config: 기본 설정을 담고 있는 `TargetConfig`입니다. 구현 타겟에 맞게 일부 값이 수정됩니다.
    /// - Returns: Shared 구현 타겟 설정이 적용된 `Target`
    static func shared(implements module: Module.Shared, config: TargetConfig) -> Self {
        var newConfig = config
        newConfig.name = Module.Shared.name + module.rawValue
        newConfig.sources = .sources
        
        if module == .designSystem {
            newConfig.resources = ["Resources/**"]
            newConfig.product = .staticFramework
        }
        
        return makeTarget(config: newConfig)
    }

    /// Shared PerfTestingSupport의 XCTest 전용 지원 타겟을 생성합니다.
    /// 앱 런타임 모듈과 XCTest import 경계를 분리하기 위한 타겟입니다.
    static func sharedPerfTestingSupportUITests(config: TargetConfig) -> Self {
        var newConfig = config
        newConfig.name = Module.Shared.name + Module.Shared.perfTestingSupport.rawValue + "UITests"
        newConfig.product = .staticFramework
        newConfig.sources = "UITests/Sources/**"
        newConfig.dependencies = [
            .shared(implements: .perfTestingSupport)
        ] + newConfig.dependencies
        newConfig.settings = .settings(
            base: [
                "ENABLE_TESTING_SEARCH_PATHS": "YES"
            ]
        )

        return makeTarget(config: newConfig)
    }
}
