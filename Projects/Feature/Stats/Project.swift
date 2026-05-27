import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Feature.name + Module.Feature.stats.rawValue,
    targets: [
        .feature(
            interface: .stats,
            config: .init(
                dependencies: [
                    .domain(interface: .goal),
                    .domain(interface: .stats),
                    .feature(interface: .common),
                    .shared(implements: .designSystem),
                    .feature(interface: .goalDetail),
                    .feature(interface: .makeGoal),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            implements: .stats,
            config: .init(
                dependencies: [
                    .domain(interface: .common),
                    .domain(interface: .goal),
                    .feature(interface: .common),
                    .feature(interface: .stats),
                    .feature(interface: .goalDetail),
                    .feature(interface: .makeGoal),
                    .domain(implements: .stats),
                    .domain(interface: .stats),
                    .core(interface: .analytics),
                    .shared(implements: .designSystem),
                    .shared(implements: .perfTestingSupport),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            testing: .stats,
            config: .init(
                dependencies: [
                    .feature(interface: .stats)
                ]
            )
        ),
        .feature(
            tests: .stats,
            config: .init(
                dependencies: [
                    .feature(testing: .stats)
                ]
            )
        ),
        .feature(
            example: .stats,
            config: .init(
                infoPlist: .extendingDefault(with: [
                    "UIUserInterfaceStyle": "Light"
                ]),
                dependencies: [
                    .feature(interface: .common),
                    .feature(interface: .stats),
                    .feature(implements: .stats),
                    .feature(interface: .goalDetail),
                    .feature(implements: .goalDetail),
                    .feature(interface: .makeGoal),
                    .feature(implements: .makeGoal),
                    .feature(interface: .proofPhoto),
                    .feature(implements: .proofPhoto),
                    .domain(interface: .stats),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(exampleUITests: .stats)
    ]
)
