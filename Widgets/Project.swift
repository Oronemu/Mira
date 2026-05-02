import ProjectDescription

let project = Project(
    name: "MiraWidgets",
    targets: [
        .target(
            name: "MiraWidgets",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "com.veilbytesoft.Mira.MiraWidgets",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Mira",
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "1",
                "CFBundleLocalizations": ["en", "ru"],
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                ],
            ]),
            sources: ["Sources/**"],
            resources: [
                "Resources/Assets.xcassets",
                "Resources/Localizable.xcstrings",
            ],
            entitlements: "Resources/MiraWidgets.entitlements",
            dependencies: [
                .project(target: "CoreKit", path: "../Core/CoreKit"),
                .project(target: "Utilities", path: "../Core/Utilities"),
                .project(target: "Persistence", path: "../Core/Persistence"),
                .project(target: "DesignSystem", path: "../Core/DesignSystem"),
            ],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
                "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": "NWH8D69Z95",
            ])
        ),
    ]
)
