import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Feature.name + Module.Feature.goalDetail.rawValue,
    targets: [
        .feature(
            interface: .goalDetail,
            config: .init(
                dependencies: [
                    .feature(interface: .proofPhoto),
                    .shared(implements: .designSystem),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            implements: .goalDetail,
            config: .init(
                dependencies: [
                    .feature(interface: .goalDetail),
                    .feature(interface: .proofPhoto),
                    .core(interface: .analytics),
                    .core(interface: .captureSession),
                    .domain(interface: .photoLog),
                    .shared(implements: .designSystem),
                    .shared(implements: .perfTestingSupport),
                    .shared(implements: .util),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            testing: .goalDetail,
            config: .init(
                dependencies: [
                    .feature(interface: .goalDetail)
                ]
            )
        ),
        .feature(
            tests: .goalDetail,
            config: .init(
                dependencies: [
                    .feature(testing: .goalDetail)
                ]
            )
        ),
        
        .feature(
            example: .goalDetail,
            config: .init(
                infoPlist: .extendingDefault(
                    with: Project.Environment.InfoPlist.launchScreen.merging(
                        [
                            "NSCameraUsageDescription": "UseCamera"
                        ],
                        uniquingKeysWith: { current, _ in current }
                    )
                ),
                dependencies: [
                    .shared(implements: .designSystem),
                    .feature(implements: .goalDetail),
                    .feature(implements: .proofPhoto),
                    .core(implements: .captureSession),
                    .domain(interface: .goal),
                    .domain(interface: .photoLog),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(exampleUITests: .goalDetail)
    ]
)
