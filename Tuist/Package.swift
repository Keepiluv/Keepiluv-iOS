// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [
            "ComposableArchitecture": .framework,
            "Kingfisher": .framework,
            "Pulse": .framework,
            "KakaoSDK": .staticLibrary
        ]
    )
#endif

// Firebase / GoogleSignIn은 akaffenberger 미러를 통해 prebuilt xcframework로 통합한다.
// 미러는 Firebase 공식 zip을 SPM `binaryTarget`으로 재포장한 것으로, Firebase가
// 의존하는 GoogleUtilities/Promises 등을 동일 패키지가 함께 제공하기 때문에
// 다른 SPM 경로(예: google/GoogleSignIn-iOS의 transitive deps)와의 sub-framework
// 분할 충돌을 구조적으로 피한다. 따라서 GoogleSignIn도 같은 미러의 product를 사용한다.
// 버전은 미러의 release tag(= Firebase 공식 버전)와 일치한다.
let package = Package(
    name: "Twix",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.2"),
        .package(url: "https://github.com/onevcat/Kingfisher", from: "8.0.0"),
        .package(url: "https://github.com/kean/Pulse", from: "5.1.4"),
        .package(url: "https://github.com/kakao/kakao-ios-sdk", from: "2.27.1"),
        .package(url: "https://github.com/akaffenberger/firebase-ios-sdk-xcframeworks", from: "12.13.0")
    ]
)
