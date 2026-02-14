// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "osu-droid-ios",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "OsuDroidiOS",
            targets: ["OsuDroidiOS"]
        ),
    ],
    dependencies: [
        // Database
        .package(url: "https://github.com/nicklockwood/ZIPFoundation.git", from: "0.9.0"),
        // Socket.IO for multiplayer
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.0.0"),
        // Firebase
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "OsuDroidiOS",
            dependencies: [
                "ZIPFoundation",
                .product(name: "SocketIO", package: "socket.io-client-swift"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
            ],
            path: "osu-droid/Sources"
        ),
    ]
)
