// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusFollowMouse",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FocusFollowMouse",
            path: "Sources"
        )
    ]
)
