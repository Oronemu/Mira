import ProjectDescription

let project = Project(
    name: "FeatureEntryDetail",
    targets: [
        .target(
            name: "FeatureEntryDetail",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.FeatureEntryDetail",
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
    ]
)
