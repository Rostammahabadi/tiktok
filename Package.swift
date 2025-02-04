// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "tiktok",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(name: "tiktok", targets: ["tiktok"])
    ],
    dependencies: [
        .package(url: "https://github.com/google/abseil-cpp-binary.git", from: "1.2024011602.0"),
        .package(url: "https://github.com/google/app-check.git", from: "10.19.2"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.29.0"),
        .package(url: "https://github.com/google/GoogleAppMeasurement.git", from: "10.28.0"),
        .package(url: "https://github.com/google/GoogleDataTransport.git", from: "9.4.0"),
        .package(url: "https://github.com/google/GoogleUtilities.git", from: "7.13.3"),
        .package(url: "https://github.com/google/grpc-binary.git", from: "1.62.2"),
        .package(url: "https://github.com/google/gtm-session-fetcher.git", from: "3.5.0"),
        .package(url: "https://github.com/google/interop-ios-for-google-sdks.git", from: "100.0.0"),
        .package(url: "https://github.com/firebase/leveldb.git", from: "1.22.5"),
        .package(url: "https://github.com/firebase/nanopb.git", from: "2.30910.0"),
        .package(url: "https://github.com/google/promises.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.2"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.4.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.18.0"),
        .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", from: "0.1.9")
    ],
    targets: [
        .executableTarget(
            name: "tiktok",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "AppCheck", package: "app-check"),
                .product(name: "GoogleAppMeasurement", package: "GoogleAppMeasurement"),
                .product(name: "GoogleDataTransport", package: "GoogleDataTransport"),
                .product(name: "GoogleUtilities", package: "GoogleUtilities"),
                .product(name: "GTMSessionFetcher", package: "gtm-session-fetcher"),
                .product(name: "leveldb", package: "leveldb"),
                .product(name: "nanopb", package: "nanopb"),
                .product(name: "Promises", package: "promises"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "SDWebImage", package: "SDWebImage"),
                .product(name: "SwiftUIX", package: "SwiftUIX")
            ],
            path: "tiktok"
        )
    ]
) 