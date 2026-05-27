import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Feature.name + Module.Feature.mainTab.rawValue,
    targets: [
        .feature(
            interface: .mainTab,
            config: .init()
        ),
        .feature(
            implements: .mainTab,
            config: .init(
                dependencies: [
                    .domain(interface: .photoLog),
                    .domain(interface: .goal),
                    .domain(interface: .notification),
                    .feature(interface: .mainTab),
                    .feature(interface: .makeGoal),
                    .core(implements: .logging),
                    .core(interface: .push),
                    .core(interface: .analytics),
                    .external(dependency: .ComposableArchitecture)
                ] + Module.Feature.allCases.filter { $0 != .mainTab }.map {  .feature(implements: $0) }
            )
        ),
        .feature(
            example: .mainTab,
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
                    .feature,
                    .core(implements: .captureSession)
                ]
            )
        ),
        .feature(exampleUITests: .mainTab)
    ]
)
