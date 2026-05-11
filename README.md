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

## Release

Pushing a tag like `v0.1.0` triggers GitHub Actions to build and publish both:

- `MyServers-arm64.zip`
- `MyServers-x86_64.zip`
