// swift-tools-version: 6.0
// JobtrackKit: the app's logic, kept out of the app target so it is unit
// tested with `swift test` on macOS. Pure Foundation: no UIKit or SwiftUI.
import PackageDescription

let package = Package(
    name: "JobtrackKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "JobtrackKit", targets: ["JobtrackKit"]),
    ],
    targets: [
        .target(name: "JobtrackKit"),
        .testTarget(name: "JobtrackKitTests", dependencies: ["JobtrackKit"]),
    ],
    swiftLanguageModes: [.v5]
)
