// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "StudyAIRecorder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StudyAIRecorder", targets: ["StudyAIRecorder"])
    ],
    targets: [
        .executableTarget(
            name: "StudyAIRecorder"
        )
    ]
)
