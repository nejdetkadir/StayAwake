# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-15

### Added
- Menu bar toggle that keeps the Mac awake, including with the lid closed (`pmset sleep 0` + `disablesleep 1`).
- Backup of the original power settings and restore when turned off.
- Remembers the chosen mode and re-applies it on launch.
- Optional launch at login via a per-user LaunchAgent.
- Colored status icon: green (awake), gray (normal), red (problem).
- Asks for permission on first launch with the standard macOS administrator prompt.
- Signed and notarized DMG for Apple silicon and Intel.
- `install.sh` to build from source, with `build` and `uninstall` modes.
