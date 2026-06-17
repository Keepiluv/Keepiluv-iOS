import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.makeModule(
    name: Module.Feature.name + Module.Feature.onboarding.rawValue,
    targets: [
        .feature(
            interface: .onboarding,
            config: .init()
        ),
        .feature(
            implements: .onboarding,
            config: .init(
                resources: ["Resources/**"],
                dependencies: [
                    .feature(interface: .onboarding),
                    .core(interface: .analytics),
                    .domain(interface: .onboarding),
                    .core(interface: .push),
                    .core(interface: .crashlytics),
                    .shared(implements: .designSystem),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(
            testing: .onboarding,
            config: .init(
                dependencies: [
                    .feature(interface: .onboarding)
                ]
            )
        ),
        .feature(
            tests: .onboarding,
            config: .init(
                dependencies: [
                    .feature(testing: .onboarding)
                ]
            )
        ),
        .feature(
            example: .onboarding,
            config: .init(
                infoPlist: .extendingDefault(with: [
                    "UIUserInterfaceStyle": "Light",
                    "DEEPLINK_HOST": "keepiluv.jiyong.xyz"
                ]),
                entitlements: .file(path: "FeatureOnboardingExample.entitlements"),
                dependencies: [
                    .feature(implements: .onboarding),
                    .domain(implements: .onboarding),
                    .domain(implements: .notification),
                    .external(dependency: .ComposableArchitecture)
                ]
            )
        ),
        .feature(exampleUITests: .onboarding)
    ]
)
