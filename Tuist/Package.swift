// swift-tools-version: 6.0
@preconcurrency import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [
            // Firebase: force static-framework linking so the App links a
            // single binary and Crashlytics symbol-upload works as expected.
            "FirebaseAnalytics": .staticFramework,
            "FirebaseCrashlytics": .staticFramework,
            "FirebaseMessaging": .staticFramework,
            "FirebaseRemoteConfig": .staticFramework,
            "FirebaseCore": .staticFramework,
            "FirebaseCoreInternal": .staticFramework,
            "FirebaseInstallations": .staticFramework,
            "FirebaseABTesting": .staticFramework,
            "FirebaseSessions": .staticFramework,
            "FirebaseRemoteConfigInterop": .staticFramework,
            "FirebaseSharedSwift": .staticFramework,
            "FirebaseCoreExtension": .staticFramework,
            "GoogleUtilities": .staticFramework,
            "GoogleDataTransport": .staticFramework,
            "GoogleAppMeasurement": .staticFramework,
            "nanopb": .staticFramework,
            "Promises": .staticFramework,
            "PromisesObjC": .staticFramework,
        ]
    )
#endif

let package = Package(
    name: "Mira",
    dependencies: [
        // MLX Swift: Apple's numerical/ML framework with LLM inference examples.
        // Provides MLX, MLXLLM, MLXLMCommon products used by MLXLocalProvider.
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "2.29.1"),
        // Firebase iOS SDK: product analytics, crash reporting, push, and
        // remote config. Only the Core/Telemetry module links these products;
        // the rest of the app talks through CoreKit protocols.
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.12.1"),
    ]
)
