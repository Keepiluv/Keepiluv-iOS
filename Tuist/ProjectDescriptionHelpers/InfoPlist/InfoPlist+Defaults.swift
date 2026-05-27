//
//  InfoPlist+Defaults.swift
//  ProjectDescriptionHelpers
//
//  Created by 정지훈 on 1/23/26.
//

import ProjectDescription

public extension Project.Environment {
    enum InfoPlist {
        public static let launchScreen: [String: Plist.Value] = [
            "UILaunchScreen": [
                "UIColorName": "LaunchScreenBackground"
            ],
            "UISupportedInterfaceOrientations": [
                "UIInterfaceOrientationPortrait"
            ]
        ]
    }
}

public extension InfoPlist {
    func mergingLaunchScreenDefaults() -> InfoPlist {
        let launchScreen = Project.Environment.InfoPlist.launchScreen
        
        switch self {
        case .default:
            return .extendingDefault(with: launchScreen)
            
        case .extendingDefault(let dict):
            let merged = dict.merging(launchScreen) { current, _ in current }
            return .extendingDefault(with: merged)
            
        default:
            return self
        }
    }

    func mergingExampleDisplayName(_ displayName: String) -> InfoPlist {
        switch self {
        case .default:
            return .extendingDefault(with: ["CFBundleDisplayName": .string(displayName)])

        case .extendingDefault(let dict):
            let merged = dict.merging(
                ["CFBundleDisplayName": .string(displayName)]
            ) { current, _ in current }
            return .extendingDefault(with: merged)

        default:
            return self
        }
    }
}
