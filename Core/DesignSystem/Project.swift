import ProjectDescription

let project = Project(
    name: "DesignSystem",
    targets: [
        .target(
            name: "DesignSystem",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.DesignSystem",
            deploymentTargets: .iOS("26.0"),
            sources: ["Sources/**"],
            resources: [
                "Resources/Stickers.xcassets",
            ],
            dependencies: [
                .project(target: "CoreKit", path: "../CoreKit"),
                .project(target: "Utilities", path: "../Utilities"),
            ],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
