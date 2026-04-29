import ProjectDescription

let project = Project(
    name: "Telemetry",
    targets: [
        .target(
            name: "Telemetry",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.veilbytesoft.Mira.Telemetry",
            deploymentTargets: .iOS("26.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "CoreKit", path: "../CoreKit"),
                .project(target: "Utilities", path: "../Utilities"),
                .external(name: "FirebaseAnalytics"),
                .external(name: "FirebaseCrashlytics"),
                .external(name: "FirebaseMessaging"),
                .external(name: "FirebaseRemoteConfig"),
            ],
            settings: .settings(base: [
                // Firebase's Swift modules aren't yet fully Sendable-clean;
                // keep concurrency checking on but tolerate the upstream
                // warnings with `minimal` until Firebase catches up.
                "SWIFT_STRICT_CONCURRENCY": "minimal",
                "SWIFT_VERSION": "6.0",
            ])
        ),
    ]
)
