# swift-create-xcframework

>[!IMPORTANT]
>This project is **unmaintained**. It is recommended that you use a fork like [segment-integrations/swift-create-xcframework](https://github.com/segment-integrations/swift-create-xcframework) that includes support for Xcode 15.

swift-create-xcframework is a very simple tool designed to wrap `xcodebuild` and the process of creating multiple frameworks for a Swift Package and merging them into a single XCFramework.

On the 23rd of June 2020, Apple announced Xcode 12 and Swift 5.3 with support for Binary Targets. Though they provide a simplified way to [include Binary Frameworks in your packages][apple-docs], they did not provide a simple way to create your XCFrameworks, with only some [documentation for the long manual process][manual-docs]. swift-create-xcframework bridges that gap.

**Note:** swift-create-xcframework pre-dates the WWDC20 announcement and is tested with Xcode 11.4 or later, but should work with Xcode 11.2 or later. You can include the generated XCFrameworks in your app manually even without Xcode 12.

## Usage

Inside your Swift Package folder you can just run:

```shell
swift create-xcframework
```

By default swift-create-xcframework will build XCFrameworks for all library products in your Package.swift, or any targets you specify on the command line (this can be for any dependencies you include as well).

Then for every target or product specified, swift-create-xcframework will:

1. Generate an Xcode Project for your package (in `.build/swift-create-xcframework`).
2. Build a `.framework` for each supported platform/SDK.
3. Merge the SDK-specific framework into an XCFramework using `xcodebuild -create-xcframework`.
4. Optionally package it up into a zip file ready for a GitHub release.

This process mirrors the [official documentation][manual-docs].

## Choosing what to build

Let's use an example `Package.swift`:

```swift
var package = Package(
    name: "example-generator",
    platforms: [
	    .ios(.v12),
    	 .macos(.v10_12)
    ],
    products: [
        .library(
            name: "ExampleGenerator",
            targets: [ "ExampleGenerator" ]),
    ],
    dependencies: [],
    targets: [
		...
	]
)
```

By default swift-create-xcframework will build `ExampleGenerator.xcframework` that supports: macosx, iphoneos, iphonesimulator. Additional `.library` products would be built automatically as well.

### Choosing Platforms

You can narrow down what gets built
If you omit the platforms specification, we'll build for all platforms that support Swift Binary Frameworks, which at the time of writing is just the Apple SDKs: macosx, iphoneos, iphonesimulator, watchos, watchsimulator, appletvos, appletvsimulator.

**Note:** Because only Apple's platforms are supported at this time, swift-create-xcframework will ignore Linux and other platforms in the Package.swift.

You can specify a subset of the platforms to build using the `--platform` option, for example:

```shell
swift create-xcframework --platform ios --platform macos ...
```

#### Catalyst

You can build your XCFrameworks with support for Mac Catalyst by specifying `--platform maccatalyst` on the command line. As you can't include or exclude Catalyst support in your `Package.swift` we don't try to build it automatically.

### Choosing Products

Because we wrap `xcodebuild`, you can actually build XCFrameworks from anything that will be mapped to an Xcode project as a Framework target. This includes all of the dependencies your Package has.

To see whats available:

```shell
swift create-xcframework --list-products
```

And then to choose what to build:

```shell
swift create-xcframework Target1 Target2 Target3...
```

By default it builds all top-level library products in your Package.swift.

## Command Line Options

Because of the low-friction to adding command line options with [swift-argument-parser](https://github.com/apple/swift-argument-parser), there are a number of useful command line options available, so `--help` should be your first port of call.

## Packaging for distribution

swift-create-xcframework provides a `--zip` option to automatically zip up your newly created XCFrameworks ready for upload to GitHub as a release artefact, or anywhere you choose.

If the target you are creating an XCFramework happens to be a dependency, swift-create-xcframework will look back into the package graph, locate the version that dependency resolved to, and append the version number to your zip file name. eg: `ArgumentParser-0.0.6.zip`

If the target you are creating is a product from the root package, unfortunately there is no standard way to identify the version number. For those cases you can specify one with `--zip-version`.

Because you're probably wanting to [distribute your binary frameworks as Swift Packages][apple-docs] `swift create-xcframework --zip` will also calculate the necessary SHA256 checksum and place it alongside the zip. eg: `ArgumentParser-0.0.6.sha256`.

## GitHub Action

swift-create-xcframework includes a GitHub Action that can kick off and automatically create an XCFramework when you tag a release in your project.

The action produces one zipped XCFramework and checksum artifact for every target specified.

**Note:** You MUST use a macOS-based runner (such as `macos-latest`) as xcodebuild doesn't run on Linux.

You can then take those artifacts and add them to your release.

An incomplete example:

### .github/workflows/create-release.yml

```yaml
name: Create Release

# Create XCFramework when a version is tagged
on:
  push:
    tags:

jobs:
  create_release:
    name: Create Release
    runs-on: macos-latest
    steps:

      - uses: actions/checkout@v2

      - name: Create XCFramework
        uses: unsignedapps/swift-create-xcframework@v2

      # Create a release
      # Upload those artifacts to the release
```

## Installation

You can install using mint:

```shell
mint install unsignedapps/swift-create-xcframework
```

Or manually:

```shell
git clone https://github.com/unsignedapps/swift-create-xcframework.git
cd swift-create-xcframework
make install
```

Either should pop the swift-create-xcframework binary into `/usr/local/bin`. And because the `swift` binary is extensible, you can then call it as a subcommand of `swift` itself:

```shell
swift create-xcframework --help
```

## Contributing

Please read the [Contribution Guide](CONTRIBUTING.md) for details on how to contribute to this project.

## License

swift-create-xcframework is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

[apple-docs]: https://developer.apple.com/documentation/swift_packages/distributing_binary_frameworks_as_swift_packages
[manual-docs]: https://help.apple.com/xcode/mac/11.4/#/dev544efab96
