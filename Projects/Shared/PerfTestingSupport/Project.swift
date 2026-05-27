import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Shared.name + Module.Shared.perfTestingSupport.rawValue,
    targets: [
        .shared(
            implements: .perfTestingSupport,
            config: .init(
                dependencies: [
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .sharedPerfTestingSupportUITests(
            config: .init()
        )
    ]
)
