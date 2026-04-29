import ProjectDescription

let project = Project(
    name: "CoreKit",
    targets: [
        .target(
            name: "CoreKit",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.CoreKit",
            deploymentTargets: .iOS("26.0"),
            sources: ["Sources/**"],
            dependencies: [],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
            ])
        ),
        .target(
            name: "CoreKitTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.veilbytesoft.Mira.CoreKitTests",
            deploymentTargets: .iOS("26.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "CoreKit"),
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
