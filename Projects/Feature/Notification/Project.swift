import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Feature.name + Module.Feature.notification.rawValue,
    targets: [
        .feature(
            interface: .notification,
            config: .init(
                dependencies: [
                    .domain(interface: .notification),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            implements: .notification,
            config: .init(
                dependencies: [
                    .feature(interface: .notification),
                    .domain(interface: .notification),
                    .shared(implements: .designSystem),
                    .shared(implements: .util),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            example: .notification,
            config: .init(
                infoPlist: .extendingDefault(with: [
                    "UIUserInterfaceStyle": "Light"
                ]),
                dependencies: [
                    .feature(implements: .notification),
                    .shared(implements: .designSystem),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(exampleUITests: .notification)
    ]
)
