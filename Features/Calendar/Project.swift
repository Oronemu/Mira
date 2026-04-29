import ProjectDescription

let project = Project(
    name: "FeatureCalendar",
    targets: [
        .target(
            name: "FeatureCalendar",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.FeatureCalendar",
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
