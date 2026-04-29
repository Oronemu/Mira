import ProjectDescription

let project = Project(
    name: "FeatureEntryList",
    targets: [
        .target(
            name: "FeatureEntryList",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.FeatureEntryList",
            deploymentTargets: .iOS("26.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "CoreKit", path: "../../Core/CoreKit"),
                .project(target: "Utilities", path: "../../Core/Utilities"),
                .project(target: "DesignSystem", path: "../../Core/DesignSystem"),
            ],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
            ])
        ),
        .target(
            name: "FeatureEntryListTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.veilbytesoft.Mira.FeatureEntryListTests",
            deploymentTargets: .iOS("26.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "FeatureEntryList"),
                .project(target: "TestSupport", path: "../../Core/TestSupport"),
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
