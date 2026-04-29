import ProjectDescription

let project = Project(
    name: "TestSupport",
    targets: [
        .target(
            name: "TestSupport",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.TestSupport",
            deploymentTargets: .iOS("26.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "CoreKit", path: "../CoreKit"),
            ],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
