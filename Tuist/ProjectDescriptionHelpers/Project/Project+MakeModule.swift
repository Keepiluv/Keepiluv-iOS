//
//  Project+MakeModule.swift
//  ProjectDescriptionHelpers
//
//  Created by 정지훈 on 12/18/25.
//

import ProjectDescription

/// `Project`를 생성하기 위한 편의 메서드를 제공하는 extension입니다.
///
/// 이 확장은 Tuist에서 `Project.init`을 직접 호출하지 않고도,
/// 모듈 단위의 `Project`를 일관된 방식으로 생성할 수 있도록 돕습니다.
///
/// 주로 `make module` 플로우에서 각 모듈의 `Project.swift`를
/// 간결하고 표준화된 형태로 구성하기 위해 사용됩니다.
///
/// **Project.swift**에서 사용됩니다.
public extension Project {
    private static var defaultModuleSettings: Settings {
        .settings(
            configurations: [
                .debug(name: "Debug"),
                .release(name: "Release"),
                .release(
                    name: "Profile",
                    settings: [
                        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
                        "COPY_PHASE_STRIP": "NO",
                        "STRIP_INSTALLED_PRODUCT": "NO",
                        "CONFIGURATION_BUILD_DIR": "$(BUILD_DIR)/Release$(EFFECTIVE_PLATFORM_NAME)",
                        "FRAMEWORK_SEARCH_PATHS": [
                            "$(inherited)",
                            "$(BUILD_DIR)/Release$(EFFECTIVE_PLATFORM_NAME)"
                        ],
                        "LIBRARY_SEARCH_PATHS": [
                            "$(inherited)",
                            "$(BUILD_DIR)/Release$(EFFECTIVE_PLATFORM_NAME)"
                        ]
                    ]
                ),
                .release(
                    name: "PerfProfile",
                    settings: [
                        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
                        "COPY_PHASE_STRIP": "NO",
                        "STRIP_INSTALLED_PRODUCT": "NO",
                        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) PERF_TESTING",
                        "CONFIGURATION_BUILD_DIR": "$(BUILD_DIR)/Release$(EFFECTIVE_PLATFORM_NAME)",
                        "FRAMEWORK_SEARCH_PATHS": [
                            "$(inherited)",
                            "$(BUILD_DIR)/Release$(EFFECTIVE_PLATFORM_NAME)"
                        ],
                        "LIBRARY_SEARCH_PATHS": [
                            "$(inherited)",
                            "$(BUILD_DIR)/Release$(EFFECTIVE_PLATFORM_NAME)"
                        ]
                    ]
                )
            ]
        )
    }

    /// `Project`모듈을 생성합니다.
    ///  내부적으로 `Project.init`과 1:1로 매핑됩니다.
    /// - Parameters:
    ///   - name: 생성할 Xcode 프로젝트의 이름입니다.
    ///   - organizationName: 저작권(Copyright) 표기를 위해 사용하는 조직(Organization)의 이름입니다.
    ///   - classPrefix: 프로젝트나 클래스 파일을 생성할 때 자동으로 붙이는 클래스 접두어입니다.
    ///   - options: 프로젝트 생성 옵션입니다(예: 자동 스킴 생성 옵션, 지역화/텍스트 설정 등).
    ///   - packages: 프로젝트에서 사용하는 Swift Package 목록입니다.
    ///   - settings: 프로젝트 Build Settings 및 Configuration을 정의합니다.
    ///   - targets: 프로젝트에 포함될 타겟 목록입니다.
    ///   - schemes: 프로젝트에 추가로 정의할 커스텀 스킴 목록입니다.
    ///   - fileHeaderTemplate: Xcode 내장 파일 템플릿으로 파일 생성 시 적용할 커스텀 헤더 템플릿입니다.
    ///   - additionalFiles: Xcode가 기본으로 추적하지 않는 파일(예: README, 스크립트, 설정 파일 등)을 프로젝트 네비게이터에 포함합니다.
    ///   - resourceSynthesizers: 리소스 접근자(Accessors)를 생성하기 위한 프로젝트 리소스 합성기(Synthesizers) 설정입니다.
    /// - Returns: 주어진 인자로 구성된 `Project` 인스턴스
    
    
    static func makeModule(
        name: String,
        organizationName: String? = nil,
        classPrefix: String? = nil,
        options: Project.Options = .options(),
        packages: [Package] = [],
        settings: Settings? = nil,
        targets: [Target] = [],
        schemes: [Scheme] = [],
        fileHeaderTemplate: FileHeaderTemplate? = nil,
        additionalFiles: [FileElement] = [],
        resourceSynthesizers: [ResourceSynthesizer] = []
    ) -> Self {
        return .init(
            name: name,
            organizationName: organizationName,
            classPrefix: classPrefix,
            options: options,
            packages: packages,
            settings: settings ?? defaultModuleSettings,
            targets: targets,
            schemes: schemes,
            fileHeaderTemplate: fileHeaderTemplate,
            additionalFiles: additionalFiles,
            resourceSynthesizers: resourceSynthesizers
        )
    }
}
