// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let targets: [String]
let dependencies: [Target.Dependency]
let defines: String

#if os(iOS)
targets = ["NESDeltaCore"]
dependencies = ["DeltaCore"]
defines = "JAVASCRIPT"
#else
targets = ["NESDeltaCore", "NESBridge"]
dependencies = ["DeltaCore", "NESBridge"]
defines = "NATIVE"
#endif

let package = Package(
    name: "NESDeltaCore",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "NESDeltaCore",
            targets: targets
        ),
    ],
    dependencies: [
        .package(name: "DeltaCore", url: "https://github.com/rileytestut/DeltaCore.git", .upToNextMajor(from: "0.1.0"))
    ],
    targets: [
        .target(
            name: "NESDeltaCore",
            dependencies: dependencies,
            path: "",
            exclude: [
                "nestopia",
                
                "NESDeltaCore.podspec",
                "NESDeltaCore.xcodeproj",
                
                "NestopiaJS/Makefile",
                "NestopiaJS/NESEmulatorBridge.cpp",
                "NestopiaJS/post.js",
                
                "NESDeltaCore/NESDeltaCore.h",
                "NESDeltaCore/Info.plist",
                
                "NESDeltaCore/Bridge/NESEmulatorBridge2.swift",
                
                "NESDeltaCore/Controller Skin/info.json",
                "NESDeltaCore/Controller Skin/iphone_portrait.pdf",
                "NESDeltaCore/Controller Skin/iphone_landscape.pdf",
                "NESDeltaCore/Controller Skin/iphone_edgetoedge_portrait.pdf",
                "NESDeltaCore/Controller Skin/iphone_edgetoedge_landscape.pdf"
            ],
            sources: [
                "NESDeltaCore/NES.swift",
                "NESDeltaCore/Bridge/NESEmulatorBridge.swift"
            ],
            resources: [
                .copy("NESDeltaCore/Controller Skin/Standard.deltaskin"),
                .copy("NESDeltaCore/Standard.deltamapping"),
                .copy("NestopiaJS/nestopia.js"),
                .copy("NestopiaJS/nestopia.html"),
                .copy("NestopiaJS/NstDatabase.xml"),
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE"),
                .define(defines)
            ]
        ),
        .target(
            name: "NESBridge",
            dependencies: ["Nestopia"],
            path: "NestopiaJS",
            exclude: [
                "Makefile",
                "nestopia.js",
                "NstDatabase.xml",
                "post.js",
            ],
            sources: [
                "NESEmulatorBridge.cpp",
            ],
            publicHeadersPath: "",
            cSettings: [
                .headerSearchPath("../nestopia/source/core"),
                .headerSearchPath("../nestopia/source/core/api"),
            ]
        ),
        .target(
            name: "Nestopia",
            path: "nestopia/source",
            exclude: [
                "nes_ntsc",
                "unix",
                
                "core/NstSoundRenderer.inl",
                "core/database/NstDatabase.xml",
                "core/NstVideoFilterHq2x.inl",
                "core/NstVideoFilterHq3x.inl",
                "core/NstVideoFilterHq4x.inl",
            ],
//            sources: [
//                "visualboyadvance-m/fex",
//                "visualboyadvance-m/src/apu",
//                "visualboyadvance-m/src/common",
//                "visualboyadvance-m/src/gba",
//                "visualboyadvance-m/src/gb",
//                "visualboyadvance-m/src/Util.cpp",
//
//                "SFML/src/SFML/Network",
//                "SFML/src/SFML/System/Err.cpp",
//                "SFML/src/SFML/System/Time.cpp",
//                "SFML/src/SFML/System/Thread.cpp",
//                "SFML/src/SFML/System/String.cpp",
//                "SFML/src/SFML/System/Unix/ThreadImpl.cpp"
//            ],
            cSettings: [
                .define("NST_NO_ZLIB"),
            ]
        ),
    ],
    
    cxxLanguageStandard: .cxx98
)
