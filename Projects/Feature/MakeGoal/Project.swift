import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Feature.name + Module.Feature.makeGoal.rawValue,
    targets: [
        .feature(
            interface: .makeGoal,
            config: .init(
                dependencies: [
                    .domain(interface: .common),
                    .domain(interface: .goal),
                    .feature(interface: .common),
                    .shared(implements: .designSystem),
                    .shared(implements: .util),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            implements: .makeGoal,
            config: .init(
                dependencies: [
                    .feature(interface: .makeGoal),
                    .feature(interface: .common),
                    .core(interface: .analytics),
                    .domain(interface: .goal),
                    .shared(implements: .designSystem),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            testing: .makeGoal,
            config: .init(
                dependencies: [
                    .feature(interface: .makeGoal)
                ]
            )
        ),
        .feature(
            tests: .makeGoal,
            config: .init(
                dependencies: [
                    .feature(testing: .makeGoal)
                ]
            )
        ),
        .feature(
            example: .makeGoal,
            config: .init(
                infoPlist: .extendingDefault(with: [
                    "UIUserInterfaceStyle": "Light"
                ]),
                dependencies: [
                    .feature(interface: .makeGoal),
                    .feature(implements: .makeGoal),
                    .domain(interface: .goal),
                    .shared(implements: .designSystem),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(exampleUITests: .makeGoal)
    ]
)
