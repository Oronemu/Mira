import ProjectDescription

let project = Project(
    name: "FeatureEntryEditor",
    targets: [
        .target(
            name: "FeatureEntryEditor",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.FeatureEntryEditor",
            deploymentTargets: .iOS("26.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "CoreKit", path: "../../Core/CoreKit"),
                .project(target: "Utilities", path: "../../Core/Utilities"),
                .project(target: "AIKit", path: "../../Core/AIKit"),
                .project(target: "DesignSystem", path: "../../Core/DesignSystem"),
            ],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
            ])
        ),
        .target(
            name: "FeatureEntryEditorTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.veilbytesoft.Mira.FeatureEntryEditorTests",
            deploymentTargets: .iOS("26.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "FeatureEntryEditor"),
                .project(target: "TestSupport", path: "../../Core/TestSupport"),
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
