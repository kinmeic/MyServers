# MyServers

MyServers is a lightweight macOS SSH client built with SwiftUI, SwiftTerm, and Citadel.

## Features

- Save server connections for quick access
- Store favorite commands per server
- Import and export server lists as JSON
- Package as a standalone macOS app

## Development

```bash
swift build
swift run MyServers
```

## Build App

```bash
./scripts/build_app.sh
open ".build/release/MyServers.app"
```

For stable Local Network permission behavior on macOS, the built app bundle now includes
`NSLocalNetworkUsageDescription` and is re-signed after packaging. For local testing the
script uses ad-hoc signing by default:

```bash
SIGNING_IDENTITY=- ./scripts/build_app.sh
```

For the most reliable System Settings integration, sign with an Apple-issued certificate:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build_app.sh
```

If you tested older builds before adding the Local Network usage description, macOS may have
cached the prior permission state. Remove the old app copy, then reset the Local Network
privacy database before retesting:

```bash
tccutil reset LocalNetwork com.myservers.app
```

## Release

Pushing a tag like `v0.1.0` triggers GitHub Actions to build and publish both:

- `MyServers-arm64.zip`
- `MyServers-x86_64.zip`
