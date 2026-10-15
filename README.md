# StayAwake

[![CI](https://github.com/nejdetkadir/StayAwake/actions/workflows/ci.yml/badge.svg)](https://github.com/nejdetkadir/StayAwake/actions/workflows/ci.yml)
![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A tiny macOS menu bar app that keeps your Mac awake, **even with the lid closed**, with a single click.
Turn it off and your original sleep settings come back.

Handy when the Mac works as a server: long builds, SSH sessions, remote agents, downloads.

## Features

- **One toggle:** disables idle sleep and lid-close sleep (`pmset sleep 0` and `pmset disablesleep 1`).
- **Restores your settings:** the original power settings are backed up before the first change and restored when you turn it off.
- **Remembers the mode:** the last chosen mode is re-applied after a restart or re-login.
- **Launch at login** through a per-user LaunchAgent (optional, on by default).
- **Colored status icon:**

  | Icon | Meaning |
  |---|---|
  | Green filled cup | Awake: the Mac will not sleep |
  | Gray cup | Normal: the Mac can sleep |
  | Red triangle | Problem, for example a missing permission or settings changed by something else |
  | Hourglass | Applying a change |

## Requirements

- macOS 12 Monterey or later, Apple silicon or Intel
- An administrator account (once, to grant permission)

## Installation

### Download (recommended)

1. Download `StayAwake-x.y.z.dmg` from the [latest release](https://github.com/nejdetkadir/StayAwake/releases/latest).
2. Open it and drag **StayAwake** to **Applications**.
3. Launch StayAwake. On first launch it asks for permission to change sleep settings (see [Security](#security)).
   Click **Allow…** and enter your password once.

The app is signed with a Developer ID and notarized by Apple.

### Build from source

Requires a Swift 6 toolchain (Xcode 16+ or the Command Line Tools: `xcode-select --install`).

```sh
git clone https://github.com/nejdetkadir/StayAwake.git
cd StayAwake
./install.sh
```

The script builds the app, copies it to `/Applications`, installs the permission rule and launches it.
Run it from a regular terminal so `sudo` can ask for your password.
To only build without installing: `./install.sh build` (output: `build/StayAwake.app`).

## Usage

Click the cup icon in the menu bar:

- **Stay Awake** turns awake mode on or off.
- **Launch at Login** starts StayAwake when you log in.
- **Quit StayAwake** quits the app. Power settings stay as they are, so the Mac remains in the chosen mode.

> [!WARNING]
> With awake mode on, the Mac keeps running with the lid closed. Don't put it in a bag while it is on battery, or it can overheat.

## How it works

When you turn **Stay Awake** on, StayAwake:

1. saves the output of `pmset -g custom` to `~/.stay-awake/pmset-backup.txt`, if no backup exists yet;
2. sets `sleep`, `disksleep`, `standby`, `autopoweroff` and `powernap` to `0`, and `tcpkeepalive` and `womp` to `1`, on all power sources; sets `autorestart` to `1` on AC power; and runs `disablesleep 1`;
3. holds `PreventUserIdleSystemSleep` and `PreventSystemSleep` power assertions while the app is running.

When you turn it off, StayAwake runs `disablesleep 0`, restores the saved values and renames the backup to `pmset-backup.txt.restored-<date>`.
If no usable backup exists, it falls back to the macOS defaults.

pmset settings are system-wide and persist across restarts, so the Mac stays in the chosen mode even when the app isn't running.
The menu bar icon and the extra power assertions are only there while the app is running.

> [!NOTE]
> The app starts when you **log in**, not when the Mac boots. With FileVault enabled, a restarted Mac waits at the unlock screen.
> Until someone logs in, network services such as SSH are not available.

## Security

Changing power settings requires root. To avoid a password prompt on every toggle, StayAwake (on first launch)
or `install.sh` adds this rule to `/etc/sudoers.d/stayawake`:

```
<your-user> ALL=(root) NOPASSWD: /usr/bin/pmset
```

The rule is validated with `visudo` before it is installed, and it only covers `/usr/bin/pmset`.
However, it allows **any** pmset arguments: any process running as your user can change power settings without a password.
If that is not acceptable for you, don't install StayAwake. [Uninstalling](#uninstall) removes the rule.

## Uninstall

1. Turn **Stay Awake** off in the menu first so your original sleep settings are restored.
2. Quit StayAwake and remove it:

   ```sh
   rm -f ~/Library/LaunchAgents/com.nejdetkadirbektas.stayawake.plist
   sudo rm -rf /Applications/StayAwake.app /etc/sudoers.d/stayawake
   ```

   If you installed from source, `./install.sh uninstall` does the same.

The `~/.stay-awake` folder (settings backup) is kept; delete it if you don't need it.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Red icon: "StayAwake doesn't have permission…" | Choose **Grant Permission…** in the menu. Check with `sudo -n /usr/bin/pmset -g`. |
| Red icon: "Stay Awake is on, but the Mac can sleep" | Something else changed the power settings. Click **Stay Awake** twice to apply it again. |
| Check the current state | `pmset -g \| grep -E 'sleep \|SleepDisabled'` |

## Development

```sh
swift build                    # debug build
swift test                     # unit tests (Swift Testing)
swift format lint -r --strict Package.swift Sources Tests
./install.sh build             # .app bundle in build/
```

Releases are built by GitHub Actions when a version tag is pushed. See [docs/RELEASING.md](docs/RELEASING.md).

| File | Purpose |
|---|---|
| `Sources/StayAwake/StayAwakeApp.swift` | Entry point, single instance check |
| `Sources/StayAwake/AppDelegate.swift` | Menu bar UI, power assertions, state |
| `Sources/StayAwake/AwakeMode.swift` | Enabling/disabling, backup and restore |
| `Sources/StayAwake/PowerStatus.swift` | Parsing `pmset` output |
| `Sources/StayAwake/PermissionSetup.swift` | First-launch permission prompt |
| `Sources/StayAwake/LaunchAgent.swift` | Launch at login |
| `Sources/StayAwake/Shell.swift` | Running `pmset` and `sudo` |
| `Support/Info.plist` | App bundle metadata |
| `scripts/build-app.sh`, `scripts/make-dmg.sh` | App bundle and notarized DMG |

Contributions are welcome. Please open an issue first for larger changes.

## License

[MIT](LICENSE)
