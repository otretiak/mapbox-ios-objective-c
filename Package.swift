// swift-tools-version:5.9
import PackageDescription

let mapboxMapsVersion: Version = "11.33.0"

let package = Package(
    name: "MapboxMapObjC",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "MapboxMapObjC", type: .dynamic, targets: ["MapboxMapObjC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mapbox/mapbox-maps-ios-binary.git", exact: mapboxMapsVersion),
    ],
    targets: [
        .target(
            name: "MapboxMapObjC",
            dependencies: [
                .product(name: "MapboxMaps", package: "mapbox-maps-ios-binary"),
            ],
            path: "MapboxMapObjC",
            exclude: ["MapboxMapObjC.h"]
        ),
    ]
)
