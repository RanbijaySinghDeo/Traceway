fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios match_setup

```sh
[bundle exec] fastlane ios match_setup
```



### ios unit_tests

```sh
[bundle exec] fastlane ios unit_tests
```

Run unit tests

### ios build

```sh
[bundle exec] fastlane ios build
```

Build TraceWay

### ios lint

```sh
[bundle exec] fastlane ios lint
```

Run SwiftLint

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
