// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "AnatomyBallistics",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "AnatomyBallistics",
            targets: ["AppModule"],
            bundleIdentifier: "com.anatomy.ballistics",
            teamIdentifier: "",
            displayVersion: "1.0.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .heart),
            accentColor: .presetColor(.red),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)
