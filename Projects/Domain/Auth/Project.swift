import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Domain.name + Module.Domain.auth.rawValue,
    targets: [
        .domain(
            interface: .auth,
            config: .init(
                dependencies: [
                    .core(interface: .storage),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .domain(
            implements: .auth,
            config: .init(
                dependencies: [
                    .domain(interface: .auth),
                    .core(implements: .logging),
                    .core(interface: .network),
                    .external(dependency: .KakaoSDKCommon),
                    .external(dependency: .KakaoSDKAuth),
                    .external(dependency: .KakaoSDKUser),
                    .external(dependency: .GoogleSignIn)
                ]
            )
        ),
        .domain(
            testing: .auth,
            config: .init(
                dependencies: [
                    .domain(interface: .auth)
                ]
            )
        ),
        .domain(
            tests: .auth,
            config: .init(
                dependencies: [
                    .domain(testing: .auth),
                    .domain(implements: .auth),
                    .core(interface: .network),
                    .core(testing: .network)
                ]
            )
        )
    ]
)
