import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Feature.name + Module.Feature.settings.rawValue,
    targets: [
        .feature(
            interface: .settings,
            config: .init(
                dependencies: [
                    .domain(interface: .notification),
                    .external(dependency: .ComposableArchitecture),
                    .shared(implements: .util),
                    .shared(implements: .designSystem)
                ]
            )
        ),
        .feature(
            implements: .settings,
            config: .init(
                dependencies: [
                    .feature(interface: .settings),
                    .core(interface: .network),
                    .core(interface: .push),
                    .domain(interface: .auth),
                    .domain(interface: .notification),
                    .domain(interface: .onboarding),
                    .shared(implements: .designSystem),
                    .shared(implements: .util),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            example: .settings,
            config: .init(
                infoPlist: .extendingDefault(with: [
                    "UIUserInterfaceStyle": "Light"
                ]),
                dependencies: [
                    .feature(implements: .settings),
                    .domain(interface: .auth),
                    .domain(interface: .onboarding),
                    .shared(implements: .designSystem),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(exampleUITests: .settings)
    ]
)
