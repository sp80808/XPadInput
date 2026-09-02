// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "XPadInput",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "XPI",
            targets: ["XPadInput"]
        ),
        .executable(
            name: "XPadTests",
            targets: ["XPadTests"]
        ),
        .library(
            name: "XPadCore",
            targets: ["XPadCore"]
        ),
        .library(
            name: "XPadTheory",
            targets: ["XPadTheory"]
        ),
        .library(
            name: "XPadController",
            targets: ["XPadController"]
        ),
        .library(
            name: "XPadMIDI",
            targets: ["XPadMIDI"]
        ),
        .library(
            name: "XPadAudio",
            targets: ["XPadAudio"]
        ),
        .library(
            name: "XPadSequencer",
            targets: ["XPadSequencer"]
        ),
        .library(
            name: "XPadUI",
            targets: ["XPadUI"]
        ),
        .library(
            name: "XPadPractice",
            targets: ["XPadPractice"]
        )
    ],
    targets: [
        .target(
            name: "XPadCore",
            dependencies: [],
            path: "Sources/XPadCore"
        ),
        .target(
            name: "XPadTheory",
            dependencies: ["XPadCore"],
            path: "Sources/XPadTheory"
        ),
        .target(
            name: "XPadController",
            dependencies: ["XPadCore", "XPadTheory"],
            path: "Sources/XPadController"
        ),
        .target(
            name: "XPadMIDI",
            dependencies: ["XPadCore", "XPadTheory"],
            path: "Sources/XPadMIDI"
        ),
        .target(
            name: "XPadAudio",
            dependencies: ["XPadCore", "XPadTheory"],
            path: "Sources/XPadAudio"
        ),
        .target(
            name: "XPadSequencer",
            dependencies: ["XPadCore", "XPadTheory", "XPadMIDI", "XPadAudio"],
            path: "Sources/XPadSequencer"
        ),
        .target(
            name: "XPadUI",
            dependencies: [
                "XPadCore",
                "XPadTheory",
                "XPadController",
                "XPadMIDI",
                "XPadAudio",
                "XPadSequencer",
                "XPadPractice"
            ],
            path: "Sources/XPadUI",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "XPadPractice",
            dependencies: ["XPadCore", "XPadTheory"],
            path: "Sources/XPadPractice"
        ),
        .executableTarget(
            name: "XPadInput",
            dependencies: ["XPadUI"],
            path: "Sources/XPadInput"
        ),
        .executableTarget(
            name: "XPadTests",
            dependencies: [
                "XPadCore",
                "XPadTheory",
                "XPadController",
                "XPadMIDI",
                "XPadAudio",
                "XPadSequencer",
                "XPadPractice",
                "XPadUI"
            ],
            path: "Sources/XPadTests"
        ),
        .testTarget(
            name: "XPadCoreTests",
            dependencies: ["XPadCore"],
            path: "Tests/XPadCoreTests"
        ),
        .testTarget(
            name: "XPadTheoryTests",
            dependencies: ["XPadCore", "XPadTheory"],
            path: "Tests/XPadTheoryTests"
        ),
        .testTarget(
            name: "XPadControllerTests",
            dependencies: ["XPadCore", "XPadTheory", "XPadController"],
            path: "Tests/XPadControllerTests"
        ),
        .testTarget(
            name: "XPadMIDITests",
            dependencies: ["XPadCore", "XPadMIDI"],
            path: "Tests/XPadMIDITests"
        ),
        .testTarget(
            name: "XPadAudioTests",
            dependencies: ["XPadCore", "XPadAudio"],
            path: "Tests/XPadAudioTests"
        ),
        .testTarget(
            name: "XPadSequencerTests",
            dependencies: ["XPadCore", "XPadTheory", "XPadMIDI", "XPadSequencer"],
            path: "Tests/XPadSequencerTests"
        ),
        .testTarget(
            name: "XPadPracticeTests",
            dependencies: ["XPadCore", "XPadTheory", "XPadPractice"],
            path: "Tests/XPadPracticeTests"
        )
    ]
)
