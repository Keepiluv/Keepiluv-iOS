//
//  TargetDependency+Modules.swift
//  Manifests
//
//  Created by 정지훈 on 12/20/25.
//

import Foundation
import ProjectDescription

/// 모듈 구조(App / Feature / Domain / Core / Shared)에 따른 `TargetDependency` 생성 규칙을 정의한 확장입니다.
///
/// 이 파일은 각 모듈 타입별로 루트 타겟, 구현 타겟, 인터페이스 타겟, 테스트 타겟에 대한
/// 의존성을 일관된 네이밍 규칙과 경로 규칙으로 생성하기 위해 존재합니다.
///
/// `Project.swift` 또는 `Target` 정의 시 문자열 기반 타겟 이름이나 경로를 직접 다루지 않고,
/// 타입 안전한 방식으로 의존성을 선언할 수 있도록 돕는 것이 목적입니다.
///
/// `Path+Modules.swift`에서 의존성을 관리하기 위해 사용됩니다.
public extension TargetDependency {
    /// 앱 루트 타겟에 대한 의존성입니다.
    static var app: Self {
        return .project(target: Module.App.name, path: .app)
    }
    
    /// 특정 앱 구현 타겟에 대한 의존성입니다.
    ///
    /// - Parameter module: 의존성을 추가할 App 모듈 식별자입니다.
    /// - Returns: App 구현 타겟을 가리키는 `TargetDependency`
    static func app(implements module: Module.App) -> Self {
        return .target(name: Module.App.name + module.rawValue)
    }
}

public extension TargetDependency {
    /// Feature 루트 타겟에 대한 의존성입니다.
    static var feature: Self {
        return .project(target: Module.Feature.name, path: .feature)
    }
    
    /// Feature 구현 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Feature` + `rawValue` 형식입니다.
    /// - Parameter module: 의존성을 추가할 Feature 모듈 식별자입니다.
    /// - Returns: Feature 구현 타겟을 가리키는 `TargetDependency`
    static func feature(implements module: Module.Feature) -> Self {
        return .project(target: Module.Feature.name + module.rawValue, path: .feature(implementation: module))
    }
    
    /// Feature 인터페이스 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Interface` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Feature 모듈 식별자입니다.
    /// - Returns: Feature 인터페이스 타겟을 가리키는 `TargetDependency`
    static func feature(interface module: Module.Feature) -> Self {
        return .project(target: Module.Feature.name + module.rawValue + "Interface", path: .feature(implementation: module))
    }
    
    /// Feature 유닛 테스트 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Tests` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Feature 모듈 식별자입니다.
    /// - Returns: Feature 테스트 타겟을 가리키는 `TargetDependency`
    static func feature(tests module: Module.Feature) -> Self {
        return .project(target: Module.Feature.name + module.rawValue + "Tests", path: .feature(implementation: module))
    }
    
    /// Feature 테스트 지원 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Testing` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Feature 모듈 식별자입니다.
    /// - Returns: Feature 테스트 지원 타겟을 가리키는 `TargetDependency`
    static func feature(testing module: Module.Feature) -> Self {
        return .project(target: Module.Feature.name + module.rawValue + "Testing", path: .feature(implementation: module))
    }
    
}

public extension TargetDependency {
    /// Domain 루트 타겟에 대한 의존성입니다.
    static var domain: Self {
        return .project(target: Module.Domain.name, path: .domain)
    }
    
    /// Domain 구현 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Domain` + `rawValue` 형식입니다.
    /// - Parameter module: 의존성을 추가할 Domain 모듈 식별자입니다.
    /// - Returns: Domain 구현 타겟을 가리키는 `TargetDependency`
    static func domain(implements module: Module.Domain) -> Self {
        return .project(target: Module.Domain.name + module.rawValue, path: .domain(implementation: module))
    }
    
    /// Domain 인터페이스 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Interface` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Domain 모듈 식별자입니다.
    /// - Returns: Domain 인터페이스 타겟을 가리키는 `TargetDependency`
    static func domain(interface module: Module.Domain) -> Self {
        return .project(target: Module.Domain.name + module.rawValue + "Interface", path: .domain(implementation: module))
    }
    
    /// Domain 유닛 테스트 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Tests` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Domain 모듈 식별자입니다.
    /// - Returns: Domain 테스트 타겟을 가리키는 `TargetDependency`
    static func domain(tests module: Module.Domain) -> Self {
        return .project(target: Module.Domain.name + module.rawValue + "Tests", path: .domain(implementation: module))
    }
    
    /// Domain 테스트 지원 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Testing` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Domain 모듈 식별자입니다.
    /// - Returns: Domain 테스트 지원 타겟을 가리키는 `TargetDependency`
    static func domain(testing module: Module.Domain) -> Self {
        return .project(target: Module.Domain.name + module.rawValue + "Testing", path: .domain(implementation: module))
    }
}

public extension TargetDependency {
    /// Core 루트 타겟에 대한 의존성입니다.
    static var core: Self {
        return .project(target: Module.Core.name, path: .core)
    }
    
    /// Core 구현 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Core` + `rawValue` 형식입니다.
    /// - Parameter module: 의존성을 추가할 Core 모듈 식별자입니다.
    /// - Returns: Core 구현 타겟을 가리키는 `TargetDependency`
    static func core(implements module: Module.Core) -> Self {
        return .project(target: Module.Core.name + module.rawValue, path: .core(implementation: module))
    }
    
    /// Core 인터페이스 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Interface` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Core 모듈 식별자입니다.
    /// - Returns: Core 인터페이스 타겟을 가리키는 `TargetDependency`
    static func core(interface module: Module.Core) -> Self {
        return .project(target: Module.Core.name + module.rawValue + "Interface", path: .core(implementation: module))
    }
    
    /// Core 유닛 테스트 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Tests` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Core 모듈 식별자입니다.
    /// - Returns: Core 테스트 타겟을 가리키는 `TargetDependency`
    static func core(tests module: Module.Core) -> Self {
        return .project(target: Module.Core.name + module.rawValue + "Tests", path: .core(implementation: module))
    }
    
    /// Core 테스트 지원 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Testing` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Core 모듈 식별자입니다.
    /// - Returns: Core 테스트 지원 타겟을 가리키는 `TargetDependency`
    static func core(testing module: Module.Core) -> Self {
        return .project(target: Module.Core.name + module.rawValue + "Testing", path: .core(implementation: module))
    }

    /// Debug 전용 CoreLogging (Pulse 포함)에 대한 의존성입니다.
    ///
    /// Debug 빌드에서만 사용되며, Pulse 로깅 기능을 포함합니다.
    /// - Returns: CoreLoggingDebug 타겟을 가리키는 `TargetDependency`
    static var coreLoggingDebug: Self {
        return .project(
            target: "CoreLoggingDebug",
            path: .core(implementation: .logging)
        )
    }
}

public extension TargetDependency {
    /// Shared 루트 타겟에 대한 의존성입니다.
    static var shared: Self {
        return .project(target: Module.Shared.name, path: .shared)
    }
    
    /// Shared 구현 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Shared` + `rawValue` 형식입니다.
    /// - Parameter module: 의존성을 추가할 Shared 모듈 식별자입니다.
    /// - Returns: Shared 구현 타겟을 가리키는 `TargetDependency`
    static func shared(implements module: Module.Shared) -> Self {
        return .project(target: Module.Shared.name + module.rawValue, path: .shared(implementation: module))
    }
    
    /// Shared 인터페이스 타겟에 대한 의존성입니다.
    ///
    /// 타겟 이름은 `Interface` 접미사를 사용합니다.
    /// - Parameter module: 의존성을 추가할 Shared 모듈 식별자입니다.
    /// - Returns: Shared 인터페이스 타겟을 가리키는 `TargetDependency`
    static func shared(interface module: Module.Shared) -> Self {
        return .project(target: Module.Shared.name + module.rawValue + "Interface", path: .shared(implementation: module))
    }

    /// Perf UITest 타겟에서만 사용하는 XCTest 지원 모듈입니다.
    static var sharedPerfTestingSupportUITests: Self {
        return .project(
            target: Module.Shared.name + Module.Shared.perfTestingSupport.rawValue + "UITests",
            path: .shared(implementation: .perfTestingSupport)
        )
    }
}
