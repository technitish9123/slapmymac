# SlapMyMac

A macOS menu bar app that plays sound effects when you physically slap your MacBook. It reads your laptop's built-in accelerometer to detect impacts and responds with customizable audio feedback.

## How It Works

SlapMyMac accesses the MacBook's HID accelerometer via IOKit to continuously monitor motion data. When it detects a sudden spike in acceleration above the gravity baseline, it triggers a sound effect. The harder you slap, the louder it gets (in dynamic mode).

## Features

- **Slap Detection** — Real-time accelerometer monitoring with configurable sensitivity
- **Sound Packs** — Bundled packs with support for custom user-installed packs (MP3/WAV/AIFF)
- **Dynamic Mode** — Volume scales with slap force
- **Menu Bar UI** — Polished SwiftUI interface with live force feedback, session stats, and controls
- **Adjustable Controls** — Sensitivity, volume, and cooldown sliders
- **Launch at Login** — Optional auto-start via ServiceManagement
- **Custom Sounds** — Drop your own sound packs into `~/Library/Application Support/SlapMyMac/CustomSounds/`

## Requirements

- macOS 14.0+
- A MacBook with a built-in accelerometer (most MacBook Pro/Air models)
- Sudo access (required for HID accelerometer access)

## Building

```bash
# Clone the repo
git clone https://github.com/user/slapmymac.git
cd slapmymac

# Build and bundle the .app
chmod +x bundle.sh
./bundle.sh
```

The build script compiles a release build with Swift Package Manager and assembles a `SlapMyMac.app` bundle with all resources.

## Running

```bash
# Run the app (requires sudo for accelerometer access)
sudo open SlapMyMac.app

# Or run the binary directly
sudo SlapMyMac.app/Contents/MacOS/SlapMyMac
```

## Custom Sound Packs

1. Open the custom sounds folder from the app settings, or navigate to:
   ```
   ~/Library/Application Support/SlapMyMac/CustomSounds/
   ```
2. Create a subfolder for your pack (e.g. `MyPack/`)
3. Add your audio files (MP3, WAV, or AIFF)
4. Add a `pack.json` file:
   ```json
   {
     "id": "MyPack",
     "name": "My Pack",
     "description": "My custom slap sounds",
     "icon": "speaker.wave.2.fill",
     "files": ["slap1.mp3", "slap2.mp3"]
   }
   ```
5. Restart the app — your pack will appear in the sound pack picker

## Project Structure

```
Sources/
├── CHIDAccelerometer/       # C wrapper for IOKit HID accelerometer API
└── SlapMyMac/
    ├── App/                 # SwiftUI app entry point
    ├── Audio/               # AudioEngine, SoundPack, SoundPackManager
    ├── Sensor/              # AccelerometerManager, SlapDetector, SlapEvent
    ├── State/               # AppState, Preferences
    ├── UI/                  # MenuBarView, SettingsView, SoundPackPicker
    ├── Utilities/           # Constants, LaunchAtLogin
    └── Resources/           # Info.plist, bundled sound packs
```

## License

MIT License — see [LICENSE](LICENSE) for details.
