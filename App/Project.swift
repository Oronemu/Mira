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
                // Crashlytics dSYM upload. Tuist resolves SPM products to
                // Derived/SourcePackages; the run script binary lives next
                // to the Crashlytics module.
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
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}",
                        "$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)",
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
                "MARKETING_VERSION": "0.4.0",
                "CURRENT_PROJECT_VERSION": "39",
                // Firebase / GoogleUtilities ship Objective-C categories
                // (e.g. `gul_dataByGzippingData:`). Static linking strips
                // their class selectors unless the linker keeps all Obj-C
                // symbols — without `-ObjC` the app crashes at launch with
                // "unrecognized selector". `-lc++` is required by some
                // Firebase transitive deps compiled as C++.
                "OTHER_LDFLAGS": "$(inherited) -ObjC",
            ])
        ),
    ],
    additionalFiles: [
        // StoreKit Configuration for local testing — attach via
        // Edit Scheme → Run → Options → StoreKit Configuration.
        "Resources/Mira.storekit",
    ]
)
