import ProjectDescription

let project = Project(
    name: "App",
    targets: [
        .target(
            name: "Mira",
            destinations: .iOS,
            product: .app,
            bundleId: "com.veilbytesoft.Mira",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: ["Sources/**"],
            resources: [
                "Resources/Assets.xcassets",
                "Resources/PrivacyInfo.xcprivacy",
                "Resources/Localizable.xcstrings",
                "Resources/InfoPlist.xcstrings",
                "Resources/GoogleService-Info.plist",
            ],
            entitlements: "Resources/Mira.entitlements",
            scripts: [
                .post(
                    script: """
                    FIREBASE_RUN="${SRCROOT}/../Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/run"
                    if [ ! -f "$FIREBASE_RUN" ]; then
                        echo "warning: Firebase Crashlytics run script not found at $FIREBASE_RUN — skipping dSYM upload"
                        exit 0
                    fi
                    "$FIREBASE_RUN" \
                        -gsp "${SRCROOT}/Resources/GoogleService-Info.plist" \
                        -p ios "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"
                    """,
                    name: "Crashlytics dSYM upload",
                    inputPaths: [
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}",
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}",
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist",
                        "$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/GoogleService-Info.plist",
                        "$(TARGET_BUILD_DIR)/$(EXECUTABLE_PATH)",
                    ],
                    basedOnDependencyAnalysis: false
                ),
            ],
            dependencies: [
                .project(target: "CoreKit", path: "../Core/CoreKit"),
                .project(target: "Utilities", path: "../Core/Utilities"),
                .project(target: "AIKit", path: "../Core/AIKit"),
                .project(target: "DesignSystem", path: "../Core/DesignSystem"),
                .project(target: "Persistence", path: "../Core/Persistence"),
                .project(target: "Subscriptions", path: "../Core/Subscriptions"),
                .project(target: "Telemetry", path: "../Core/Telemetry"),
                .project(target: "FeatureEntryList", path: "../Features/EntryList"),
                .project(target: "FeatureEntryEditor", path: "../Features/EntryEditor"),
                .project(target: "FeatureEntryDetail", path: "../Features/EntryDetail"),
                .project(target: "FeatureCalendar", path: "../Features/Calendar"),
                .project(target: "FeatureAskMira", path: "../Features/AskMira"),
                .project(target: "FeatureInsights", path: "../Features/Insights"),
                .project(target: "FeatureOnboarding", path: "../Features/Onboarding"),
                .project(target: "FeaturePaywall", path: "../Features/Paywall"),
                .project(target: "FeatureSettings", path: "../Features/Settings"),
                .project(target: "FeatureStats", path: "../Features/Stats"),
                .project(target: "MiraWidgets", path: "../Widgets"),
            ],
            settings: .settings(base: [
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_VERSION": "6.0",
                "TARGETED_DEVICE_FAMILY": "1",
                "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
                "DEVELOPMENT_TEAM": "NWH8D69Z95",
                "CODE_SIGN_STYLE": "Automatic",
                "MARKETING_VERSION": "0.5.0",
                "CURRENT_PROJECT_VERSION": "53",
                // Firebase / GoogleUtilities ship Objective-C categories
                // (e.g. `gul_dataByGzippingData:`). Static linking strips
                // their class selectors unless the linker keeps all Obj-C
                // symbols — without `-ObjC` the app crashes at launch with
                // "unrecognized selector". `-lc++` is required by some
                // Firebase transitive deps compiled as C++.
                "OTHER_LDFLAGS": "$(inherited) -ObjC",
                // Alternate app icons. Names match the .appiconset folders
                // in Assets.xcassets and the AppIconOption enum the
                // settings UI consults. Adding a new alternate means: new
                // .appiconset, this list, and one enum case.
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES": "AppIcon-Calm AppIcon-Solace AppIcon-Quiet AppIcon-Reflect AppIcon-Stoic AppIcon-Editorial AppIcon-Minimal",
                "ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "YES",
            ])
        ),
    ],
    schemes: [
        .scheme(
            name: "Mira",
            shared: true,
            buildAction: .buildAction(targets: ["Mira"]),
            runAction: .runAction(
                configuration: "Debug",
                options: .options(storeKitConfigurationPath: "Resources/Mira.storekit")
            ),
            archiveAction: .archiveAction(configuration: "Release"),
            profileAction: .profileAction(configuration: "Release"),
            analyzeAction: .analyzeAction(configuration: "Debug")
        ),
    ],
    additionalFiles: [
        "Resources/Mira.storekit",
    ]
)
