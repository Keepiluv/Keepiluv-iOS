import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Feature.name + Module.Feature.auth.rawValue,
    targets: [
        .feature(
            interface: .auth,
            config: .init(
                dependencies: [
                    .domain(interface: .auth),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            implements: .auth,
            config: .init(
                dependencies: [
                    .feature(interface: .auth),
                    .domain(interface: .auth),
                    .domain(implements: .auth),
                    .core(implements: .logging),
                    .core(interface: .analytics),
                    .core(interface: .crashlytics),
                    .shared(implements: .designSystem),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),    
        .feature(
            example: .auth,
            config: .init(
                dependencies: [
                    .feature(interface: .auth),
                    .feature(implements: .auth),
                    .domain(interface: .auth),
                    .core(implements: .logging),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(exampleUITests: .auth)
    ]
)
