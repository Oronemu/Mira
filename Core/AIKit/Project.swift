import ProjectDescription

let project = Project(
    name: "AIKit",
    targets: [
        .target(
            name: "AIKit",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.AIKit",
            deploymentTargets: .iOS("26.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "CoreKit", path: "../CoreKit"),
                .project(target: "Utilities", path: "../Utilities"),
                .external(name: "MLXLLM"),
                .external(name: "MLXLMCommon"),
            ],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
            ])
        ),
        .target(
            name: "AIKitTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.veilbytesoft.Mira.AIKitTests",
            deploymentTargets: .iOS("26.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "AIKit"),
                .project(target: "CoreKit", path: "../CoreKit"),
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
