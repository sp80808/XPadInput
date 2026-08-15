// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XPadInput",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "XPadInput",
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
        )
    ],
    targets: [
        .target(
            name: "XPadCore",
            dependencies: []
        ),
        .target(
            name: "XPadTheory",
            dependencies: ["XPadCore"]
        ),
        .target(
            name: "XPadController",
            dependencies: ["XPadCore", "XPadTheory"]
        ),
        .target(
            name: "XPadMIDI",
            dependencies: ["XPadCore", "XPadTheory"]
        ),
        .target(
            name: "XPadAudio",
            dependencies: ["XPadCore", "XPadTheory"]
        ),
        .target(
            name: "XPadSequencer",
            dependencies: ["XPadCore", "XPadTheory", "XPadMIDI", "XPadAudio"]
        ),
        .target(
            name: "XPadUI",
            dependencies: ["XPadCore", "XPadTheory", "XPadController", "XPadMIDI", "XPadAudio", "XPadSequencer"]
        ),
        .executableTarget(
            name: "XPadInput",
            dependencies: [
                "XPadCore",
                "XPadTheory",
                "XPadController",
                "XPadMIDI",
                "XPadAudio",
                "XPadSequencer",
                "XPadUI"
            ]
        ),
        .testTarget(
            name: "XPadCoreTests",
            dependencies: ["XPadCore"]
        ),
        .testTarget(
            name: "XPadTheoryTests",
            dependencies: ["XPadCore", "XPadTheory"]
        ),
        .testTarget(
            name: "XPadControllerTests",
            dependencies: ["XPadCore", "XPadTheory", "XPadController"]
        ),
        .testTarget(
            name: "XPadMIDITests",
            dependencies: ["XPadCore", "XPadTheory", "XPadMIDI"]
        ),
        .testTarget(
            name: "XPadAudioTests",
            dependencies: ["XPadCore", "XPadTheory", "XPadAudio"]
        ),
        .testTarget(
            name: "XPadSequencerTests",
            dependencies: ["XPadCore", "XPadTheory", "XPadMIDI", "XPadSequencer"]
        )
    ]
)
