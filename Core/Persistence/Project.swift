import ProjectDescription

let project = Project(
    name: "Persistence",
    targets: [
        .target(
            name: "Persistence",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.Persistence",
            deploymentTargets: .iOS("26.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "CoreKit", path: "../CoreKit"),
                .project(target: "Utilities", path: "../Utilities"),
            ],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
            ])
        ),
        .target(
            name: "PersistenceTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.veilbytesoft.Mira.PersistenceTests",
            deploymentTargets: .iOS("26.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "Persistence"),
                .project(target: "TestSupport", path: "../TestSupport"),
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
