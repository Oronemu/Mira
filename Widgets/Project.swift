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
            scripts: [
                .post(
                    script: """
                    FIREBASE_RUN="${SRCROOT}/../Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/run"
                    if [ ! -f "$FIREBASE_RUN" ]; then
                        echo "warning: Firebase Crashlytics run script not found at $FIREBASE_RUN — skipping dSYM upload"
                        exit 0
                    fi
                    "$FIREBASE_RUN" \
                        -gsp "${SRCROOT}/../App/Resources/GoogleService-Info.plist" \
                        -p ios "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"
                    """,
                    name: "Crashlytics dSYM upload",
                    inputPaths: [
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}",
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}",
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist",
                        "$(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)",
                    ],
                    basedOnDependencyAnalysis: false
                ),
            ],
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
